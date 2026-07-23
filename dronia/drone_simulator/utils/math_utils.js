/** Utilitaires mathématiques pour la simulation du drone. */

/** Mètres par degré de latitude (approximation sphérique). */
export const METERS_PER_DEG_LAT = 111_320;

export function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

/**
 * Rapproche `current` de `target` d'au plus `maxDelta`.
 * Sert à lisser les vitesses pour un mouvement fluide (pas instantané).
 */
export function approach(current, target, maxDelta) {
  const delta = target - current;
  if (Math.abs(delta) <= maxDelta) return target;
  return current + Math.sign(delta) * maxDelta;
}

/** Normalise un angle en degrés dans [0, 360). */
export function wrapDegrees(angle) {
  return ((angle % 360) + 360) % 360;
}

export function degToRad(deg) {
  return (deg * Math.PI) / 180;
}

/** Convertit un déplacement en mètres (nord / est) en deltas lat / lng. */
export function metersToLatLng(dNorth, dEast, latitude) {
  return {
    dLat: dNorth / METERS_PER_DEG_LAT,
    dLng: dEast / (METERS_PER_DEG_LAT * Math.cos(degToRad(latitude))),
  };
}

/** Distance approximative en mètres entre deux points GPS proches. */
export function distanceMeters(lat1, lng1, lat2, lng2) {
  const dNorth = (lat2 - lat1) * METERS_PER_DEG_LAT;
  const dEast =
    (lng2 - lng1) * METERS_PER_DEG_LAT * Math.cos(degToRad(lat1));
  return Math.hypot(dNorth, dEast);
}

/** Cap (en degrés, 0 = nord, sens horaire) du point 1 vers le point 2. */
export function bearingDegrees(lat1, lng1, lat2, lng2) {
  const dNorth = (lat2 - lat1) * METERS_PER_DEG_LAT;
  const dEast =
    (lng2 - lng1) * METERS_PER_DEG_LAT * Math.cos(degToRad(lat1));
  return wrapDegrees((Math.atan2(dEast, dNorth) * 180) / Math.PI);
}

/** Arrondit `value` à `decimals` décimales. */
export function round(value, decimals) {
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}
