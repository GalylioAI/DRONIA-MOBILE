"""
Field monitoring router — proxy Copernicus Sentinel Hub + Open-Meteo.

Reproduit l'API `/api/field-monitoring` (ancien proxy Next.js du VPS) côté
FastAPI, pour que la page « Surveillance des Cultures » de l'app mobile passe
par le backend unique (HF Spaces) au lieu d'appeler Copernicus en direct.

POST /field-monitoring, body JSON {action: ...}. Actions :
  - vegetation  : série temporelle d'indices (NDVI/NDRE/…) — Statistics API
  - soilMoisture: humidité du sol (Sentinel-1 SAR)          — Statistics API
  - weather     : météo journalière                          — Open-Meteo
  - heatmap     : image colorisée de l'indice (PNG base64)   — Process API

Le format des réponses respecte EXACTEMENT ce que parse l'app
(`EosdaApiService`), donc aucune modification Flutter n'est nécessaire.
"""
import os
import io
import math
import time
import base64
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import httpx
import numpy as np
from PIL import Image
from fastapi import APIRouter
from pydantic import BaseModel

from utils.logger import setup_logger

logger = setup_logger(__name__)

router = APIRouter(tags=["Field Monitoring"])

# --- Configuration Copernicus Sentinel Hub --------------------------------
# Identifiants OAuth2 (client_credentials). Surchargeables via les secrets HF
# Spaces ; les valeurs par défaut sont celles déjà présentes dans l'app
# (déjà exposées dans l'historique git — à roter dans le dashboard CDSE).
SH_CLIENT_ID = os.getenv("SENTINEL_CLIENT_ID", "sh-72c90811-48eb-40a4-b050-392ba0d6fc26")
SH_CLIENT_SECRET = os.getenv("SENTINEL_CLIENT_SECRET", "xk02sdFCOMt0ou2WzWg6SbdyhG6ahSBn")
SH_TOKEN_URL = (
    "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/"
    "protocol/openid-connect/token"
)
SH_STATISTICS_URL = "https://sh.dataspace.copernicus.eu/api/v1/statistics"
SH_PROCESS_URL = "https://sh.dataspace.copernicus.eu/api/v1/process"

# Scènes Sentinel-2 acceptées jusqu'à ce taux de couverture nuageuse (%).
MAX_CLOUD = 40

# Plage de valeurs valides par indice (au-delà = bruit → nodata pour la grille).
_INDEX_RANGE = {
    "ndvi": (-1.0, 1.0), "ndre": (-1.0, 1.0), "ndmi": (-1.0, 1.0),
    "ndwi": (-1.0, 1.0), "msavi": (-1.0, 1.0), "reci": (-1.0, 20.0),
}

# Cache de token au niveau process (un token CDSE vit ~10 min).
_token_cache: dict = {"token": None, "expiry": 0.0}


class FieldMonitoringRequest(BaseModel):
    action: str
    polygon: Optional[list] = None       # [[lng, lat], ...]
    centroid: Optional[dict] = None      # {lat, lng}
    point: Optional[dict] = None         # {lat, lng}
    index: Optional[str] = "ndvi"
    gridSize: Optional[int] = 20
    dateStart: Optional[str] = None
    dateEnd: Optional[str] = None


# ============ Evalscripts ============

# (bandes d'entrée, formule de l'indice) par code d'indice de végétation.
_VEG_BANDS: dict = {
    "ndvi": ('["B04", "B08", "dataMask"]', "(sample.B08 - sample.B04) / (sample.B08 + sample.B04)"),
    "ndre": ('["B05", "B08", "dataMask"]', "(sample.B08 - sample.B05) / (sample.B08 + sample.B05)"),
    "msavi": ('["B04", "B08", "dataMask"]', "(2*sample.B08 + 1 - Math.sqrt(Math.pow(2*sample.B08+1, 2) - 8*(sample.B08-sample.B04))) / 2"),
    "reci": ('["B05", "B08", "dataMask"]', "(sample.B08 / sample.B05) - 1"),
    "ndmi": ('["B08", "B11", "dataMask"]', "(sample.B08 - sample.B11) / (sample.B08 + sample.B11)"),
    "ndwi": ('["B03", "B08", "dataMask"]', "(sample.B03 - sample.B08) / (sample.B03 + sample.B08)"),
}


def _veg_evalscript(index: str) -> str:
    inp, formula = _VEG_BANDS.get((index or "ndvi").lower(), _VEG_BANDS["ndvi"])
    return f"""//VERSION=3
function setup() {{
  return {{
    input: [{{bands: {inp}}}],
    output: [
      {{id: "default", bands: 1, sampleType: "FLOAT32"}},
      {{id: "dataMask", bands: 1}}
    ]
  }};
}}
function evaluatePixel(sample) {{
  let v = {formula};
  return {{ default: [v], dataMask: [sample.dataMask] }};
}}
"""


def _soil_evalscript() -> str:
    return """//VERSION=3
function setup() {
  return {
    input: [{bands: ["VV", "VH", "dataMask"]}],
    output: [
      {id: "default", bands: 3, sampleType: "FLOAT32"},
      {id: "dataMask", bands: 1}
    ]
  };
}
function evaluatePixel(sample) {
  let vv = sample.VV;
  let vh = sample.VH;
  let ratio = vh / (vv + 0.001);
  let moisture = Math.max(0, Math.min(1, (ratio + 0.5) * 0.8));
  return { default: [moisture, vv, vh], dataMask: [sample.dataMask] };
}
"""


def _raw_evalscript(index: str) -> str:
    """Valeur brute de l'indice (1 bande FLOAT32), -9999 hors champ (dataMask=0)."""
    inp, formula = _VEG_BANDS.get((index or "ndvi").lower(), _VEG_BANDS["ndvi"])
    return f"""//VERSION=3
function setup() {{
  return {{
    input: [{{bands: {inp}}}],
    output: {{bands: 1, sampleType: "FLOAT32"}}
  }};
}}
function evaluatePixel(sample) {{
  if (sample.dataMask == 0) return [-9999];
  let v = {formula};
  return [v];
}}
"""


def _heatmap_evalscript(index: str) -> str:
    """Rampe de couleur rouge→vert (RGBA PNG) pour la superposition carte."""
    inp, formula = _VEG_BANDS.get((index or "ndvi").lower(), _VEG_BANDS["ndvi"])
    return f"""//VERSION=3
function setup() {{
  return {{
    input: [{{bands: {inp}}}],
    output: {{bands: 4}}
  }};
}}
function evaluatePixel(sample) {{
  if (sample.dataMask === 0) return [0, 0, 0, 0];
  let v = {formula};
  let r, g, b;
  if (v < 0.2) {{ r = 0.84; g = 0.19; b = 0.15; }}
  else if (v < 0.4) {{ r = 0.99; g = 0.68; b = 0.38; }}
  else if (v < 0.6) {{ r = 1.0; g = 1.0; b = 0.40; }}
  else if (v < 0.8) {{ r = 0.40; g = 0.74; b = 0.39; }}
  else {{ r = 0.0; g = 0.41; b = 0.22; }}
  return [r, g, b, 1];
}}
"""


# ============ Helpers ============

def _ring(polygon: list) -> list:
    """Anneau GeoJSON fermé [[lng, lat], …] (1er point == dernier)."""
    ring = [[float(p[0]), float(p[1])] for p in (polygon or [])]
    if len(ring) >= 3 and ring[0] != ring[-1]:
        ring.append(ring[0])
    return ring


def _iso(day: str, end: bool = False) -> str:
    """'YYYY-MM-DD' → instant ISO UTC (début ou fin de journée)."""
    return f"{day}T23:59:59Z" if end else f"{day}T00:00:00Z"


def _pct(stats: dict, k: int):
    """Lit un percentile quelle que soit la clé renvoyée ('50.0', '50', 50)."""
    p = stats.get("percentiles") or {}
    for key in (f"{k}.0", str(k), k, float(k)):
        if key in p:
            return p[key]
    return None


def _has_data(stats: dict) -> bool:
    sc = stats.get("sampleCount", 0) or 0
    nd = stats.get("noDataCount", 0) or 0
    return sc > 0 and nd < sc


async def _get_token(client: httpx.AsyncClient) -> str:
    now = time.time()
    if _token_cache["token"] and _token_cache["expiry"] > now + 60:
        return _token_cache["token"]
    resp = await client.post(
        SH_TOKEN_URL,
        data={
            "grant_type": "client_credentials",
            "client_id": SH_CLIENT_ID,
            "client_secret": SH_CLIENT_SECRET,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    resp.raise_for_status()
    j = resp.json()
    _token_cache["token"] = j["access_token"]
    _token_cache["expiry"] = now + float(j.get("expires_in", 300))
    return _token_cache["token"]


async def _statistics(
    client: httpx.AsyncClient,
    token: str,
    ring: list,
    date_start: str,
    date_end: str,
    evalscript: str,
    data_type: str,
    interval: str,
    max_cloud: Optional[int],
) -> list:
    time_range = {"from": _iso(date_start), "to": _iso(date_end, True)}
    data_filter: dict = {"timeRange": time_range}
    if max_cloud is not None:
        data_filter["maxCloudCoverage"] = max_cloud
        data_filter["mosaickingOrder"] = "mostRecent"
    body = {
        "input": {
            "bounds": {
                "geometry": {"type": "Polygon", "coordinates": [ring]},
                "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
            },
            "data": [{"dataFilter": data_filter, "type": data_type}],
        },
        "aggregation": {
            "timeRange": time_range,
            "aggregationInterval": {"of": interval},
            "evalscript": evalscript,
        },
        "calculations": {
            "default": {"statistics": {"default": {"percentiles": {"k": [25, 50, 75]}}}}
        },
    }
    resp = await client.post(
        SH_STATISTICS_URL,
        json=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    resp.raise_for_status()
    return resp.json().get("data", [])


# ============ Actions ============

async def _action_vegetation(client, token, req: FieldMonitoringRequest) -> dict:
    intervals = await _statistics(
        client, token, _ring(req.polygon), req.dateStart, req.dateEnd,
        _veg_evalscript(req.index), "sentinel-2-l2a", "P1D", MAX_CLOUD,
    )
    out = []
    for it in intervals:
        bands = ((it.get("outputs") or {}).get("default") or {}).get("bands") or {}
        stats = (bands.get("B0") or {}).get("stats") or {}
        if not _has_data(stats):
            continue
        out.append({
            "date": it["interval"]["from"][:10],
            "average": stats.get("mean"),
            "min": stats.get("min"),
            "max": stats.get("max"),
            "median": _pct(stats, 50),
            "q1": _pct(stats, 25),
            "q3": _pct(stats, 75),
        })
    out.sort(key=lambda x: x["date"])
    return {"success": True, "data": out}


async def _action_soil_moisture(client, token, req: FieldMonitoringRequest) -> dict:
    intervals = await _statistics(
        client, token, _ring(req.polygon), req.dateStart, req.dateEnd,
        _soil_evalscript(), "sentinel-1-grd", "P5D", None,
    )
    out = []
    for it in intervals:
        bands = ((it.get("outputs") or {}).get("default") or {}).get("bands") or {}
        b0 = (bands.get("B0") or {}).get("stats") or {}
        b1 = (bands.get("B1") or {}).get("stats") or {}
        b2 = (bands.get("B2") or {}).get("stats") or {}
        if not _has_data(b0):
            continue
        out.append({
            "date": it["interval"]["from"][:10],
            "moisture": b0.get("mean"),
            "vv": b1.get("mean"),
            "vh": b2.get("mean"),
        })
    out.sort(key=lambda x: x["date"])
    return {"success": True, "data": out}


async def _action_heatmap(client, token, req: FieldMonitoringRequest) -> dict:
    body = {
        "input": {
            "bounds": {
                "geometry": {"type": "Polygon", "coordinates": [_ring(req.polygon)]},
                "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
            },
            "data": [{
                "dataFilter": {
                    "timeRange": {"from": _iso(req.dateStart), "to": _iso(req.dateEnd, True)},
                    "maxCloudCoverage": MAX_CLOUD,
                    # Scène la PLUS CLAIRE de la plage (comme le web/EO Browser),
                    # pas la plus récente — évite une scène nuageuse/sèche.
                    "mosaickingOrder": "leastCC",
                },
                "type": "sentinel-2-l2a",
            }],
        },
        "output": {
            "width": 512,
            "height": 512,
            "responses": [{"identifier": "default", "format": {"type": "image/png"}}],
        },
        "evalscript": _heatmap_evalscript(req.index),
    }
    resp = await client.post(
        SH_PROCESS_URL,
        json=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "image/png",
        },
    )
    resp.raise_for_status()
    b64 = base64.b64encode(resp.content).decode()
    return {"success": True, "imageUrl": f"data:image/png;base64,{b64}"}


async def _action_point(client, token, req: FieldMonitoringRequest) -> dict:
    """Valeur moyenne de l'indice sur ~30 m autour d'un point (tooltip carte)."""
    p = req.point or {}
    lat, lng = p.get("lat"), p.get("lng")
    if lat is None or lng is None:
        return {"success": False, "error": "point {lat,lng} requis"}
    off = 0.00027  # ~30 m à l'équateur
    ring = [
        [lng - off, lat - off], [lng + off, lat - off],
        [lng + off, lat + off], [lng - off, lat + off], [lng - off, lat - off],
    ]
    end = datetime.now(timezone.utc).date()
    start = end - timedelta(days=30)
    intervals = await _statistics(
        client, token, ring, start.isoformat(), end.isoformat(),
        _veg_evalscript(req.index), "sentinel-2-l2a", "P30D", MAX_CLOUD,
    )
    value = None
    for it in intervals:
        bands = ((it.get("outputs") or {}).get("default") or {}).get("bands") or {}
        stats = (bands.get("B0") or {}).get("stats") or {}
        if _has_data(stats):
            value = stats.get("mean")
    return {"success": True, "value": value}


async def _action_grid(client, token, req: FieldMonitoringRequest) -> dict:
    """Matrice gridSize×gridSize de valeurs d'indice (Process API → TIFF FLOAT32).

    Renvoyée en ordre TIFF (rangée 0 = nord/haut), row-major ; l'app reconstruit
    les cellules et filtre par polygone. Les pixels hors champ ou aberrants
    (non finis, |v| ≥ 100) sont marqués -9999 (= nodata, ignorés par l'app).
    """
    g = max(2, min(int(req.gridSize or 20), 128))
    body = {
        "input": {
            "bounds": {
                "geometry": {"type": "Polygon", "coordinates": [_ring(req.polygon)]},
                "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
            },
            "data": [{
                "dataFilter": {
                    "timeRange": {"from": _iso(req.dateStart), "to": _iso(req.dateEnd, True)},
                    "maxCloudCoverage": MAX_CLOUD,
                    # Scène la PLUS CLAIRE de la plage (comme le web/EO Browser),
                    # pas la plus récente — évite une scène nuageuse/sèche.
                    "mosaickingOrder": "leastCC",
                },
                "type": "sentinel-2-l2a",
            }],
        },
        "output": {
            "width": g,
            "height": g,
            "responses": [{"identifier": "default", "format": {"type": "image/tiff"}}],
        },
        "evalscript": _raw_evalscript(req.index),
    }
    resp = await client.post(
        SH_PROCESS_URL,
        json=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "image/tiff",
        },
    )
    resp.raise_for_status()
    arr = np.array(Image.open(io.BytesIO(resp.content)), dtype="float32").reshape(g, g)
    # Plage valide par indice : hors plage = bruit numérique (dénominateur ~0
    # sur eau/ombre) → nodata, pour une heatmap propre.
    lo, hi = _INDEX_RANGE.get((req.index or "ndvi").lower(), (-1.0, 1.0))
    values = []
    for v in arr.flatten().tolist():
        if not math.isfinite(v) or v < lo or v > hi:
            values.append(-9999.0)
        else:
            values.append(round(v, 4))
    return {"success": True, "gridSize": g, "values": values}


async def _action_weather(client, req: FieldMonitoringRequest) -> dict:
    c = req.centroid or {}
    lat, lng = c.get("lat"), c.get("lng")
    if lat is None or lng is None:
        return {"success": False, "error": "centroid {lat,lng} requis"}

    daily = "temperature_2m_max,temperature_2m_min,precipitation_sum"
    by_date: dict = {}

    async def _fetch(url: str):
        params = {
            "latitude": lat, "longitude": lng,
            "start_date": req.dateStart, "end_date": req.dateEnd,
            "daily": daily, "timezone": "auto",
        }
        try:
            r = await client.get(url, params=params)
            if r.status_code != 200:
                return
            d = (r.json() or {}).get("daily") or {}
            times = d.get("time") or []
            tmax = d.get("temperature_2m_max") or []
            tmin = d.get("temperature_2m_min") or []
            prcp = d.get("precipitation_sum") or []
            for i, day in enumerate(times):
                # On ne réécrit pas une date déjà remplie par l'archive.
                if day in by_date and by_date[day]["dailyPrecipitation"] is not None:
                    continue
                by_date[day] = {
                    "date": day,
                    "tempMax": tmax[i] if i < len(tmax) else None,
                    "tempMin": tmin[i] if i < len(tmin) else None,
                    "dailyPrecipitation": (prcp[i] if i < len(prcp) else 0) or 0,
                }
        except Exception as e:  # noqa: BLE001
            logger.warning(f"Open-Meteo {url} : {e}")

    # Archive (jours passés consolidés) puis forecast (jours récents + à venir).
    await _fetch("https://archive-api.open-meteo.com/v1/archive")
    await _fetch("https://api.open-meteo.com/v1/forecast")

    rows = sorted(by_date.values(), key=lambda x: x["date"])
    acc = 0.0
    for row in rows:
        acc += row.get("dailyPrecipitation") or 0.0
        row["accumulatedPrecipitation"] = round(acc, 2)
    return {"success": True, "data": rows}


# ============ Route ============

@router.post("/field-monitoring")
async def field_monitoring(req: FieldMonitoringRequest) -> dict:
    """Point d'entrée unique de la page « Surveillance des Cultures »."""
    action = (req.action or "").strip()
    try:
        if action == "weather":
            async with httpx.AsyncClient(timeout=60) as client:
                return await _action_weather(client, req)

        # Les autres actions nécessitent Copernicus Sentinel Hub.
        async with httpx.AsyncClient(timeout=90) as client:
            token = await _get_token(client)
            if action == "vegetation":
                return await _action_vegetation(client, token, req)
            if action == "soilMoisture":
                return await _action_soil_moisture(client, token, req)
            if action == "heatmap":
                return await _action_heatmap(client, token, req)
            if action == "point":
                return await _action_point(client, token, req)
            if action == "grid":
                return await _action_grid(client, token, req)
        return {"success": False, "error": f"action inconnue: {action}"}
    except httpx.HTTPStatusError as e:
        detail = e.response.text[:300] if e.response is not None else str(e)
        logger.error(f"field-monitoring {action} → HTTP {e.response.status_code}: {detail}")
        return {"success": False, "error": f"upstream {e.response.status_code}: {detail}"}
    except Exception as e:  # noqa: BLE001
        logger.error(f"field-monitoring {action} → {e}")
        return {"success": False, "error": str(e)}
