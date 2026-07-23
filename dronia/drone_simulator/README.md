# Simulateur de drone DJI — DronIA

Simulateur WebSocket qui remplace temporairement un drone DJI réel pour
tester la logique de pilotage de l'application Flutter. Le jour où le
drone physique arrive, il suffit de remplacer `DroneSimulatorService`
côté Flutter par une implémentation basée sur le SDK DJI — le reste de
l'application ne change pas.

```text
Flutter App
      │
      │ WebSocket (ws://localhost:8080)
      ▼
Drone Simulator (Node.js)
      │
      ▼
Drone virtuel (logique + état)
```

## Démarrage

```bash
cd drone_simulator
npm install
npm start          # ws://localhost:8080 (PORT=9090 npm start pour changer)
```

Le serveur expose deux choses sur le même port :

- `ws://localhost:8080` — le WebSocket utilisé par l'app Flutter
  (c'est **l'app mobile qui pilote** : elle seule envoie les commandes) ;
- `http://localhost:8080` — la **vue du drone en direct** (spectateur,
  aucune commande) : scène 3D Three.js où le vrai modèle DJI
  (`assets/Drones/`) survole l'**imagerie satellite réelle** de sa
  position GPS (tuiles ESRI World Imagery), avec hélices qui tournent en
  vol (disques de flou — les pales sont fusionnées dans le .glb), ombre
  au sol, ligne d'altitude, caméra qui suit le drone (glisser pour
  orbiter) ; plus la vue du dessus (trace du vol), les tuiles de
  télémétrie et le journal des **commandes reçues** depuis l'app mobile
  — chaque commande s'affiche en flash au-dessus du drone.
  Nécessite une connexion internet (CDN Three.js + tuiles satellite) ;
  hors ligne, le sol retombe sur un vert uni.

Côté Flutter, l'URL est lue via `Environment.droneSimulatorWsUrl` :

- valeur par défaut : `ws://localhost:8080` (réécrite en `ws://10.0.2.2:8080`
  sur l'émulateur Android) ;
- surchargeable avec la clé `DRONE_SIM_WS_URL` dans `dronia/.env`
  (ex. `DRONE_SIM_WS_URL=ws://192.168.1.20:8080` pour un téléphone physique).

## Protocole

### Commandes (Flutter → simulateur)

Texte brut (`UP`) ou JSON :

```json
{ "command": "UP", "speed": 2 }
```

| Commande | Effet |
|---|---|
| `TAKEOFF` | altitude passe à 1 m puis monte progressivement à 5 m |
| `LAND` | descente jusqu'à 0, état `Idle` |
| `UP` / `DOWN` | change l'altitude |
| `FORWARD` / `BACKWARD` | avance / recule selon le cap (yaw) |
| `LEFT` / `RIGHT` | translation latérale |
| `ROTATE_LEFT` / `ROTATE_RIGHT` | modifie le yaw |
| `STOP` | arrête tout mouvement (état `Stopped`) |
| `RETURN_HOME` | revient au point de décollage puis atterrit |

`speed` est optionnel (m/s pour les déplacements, °/s pour les rotations).
Les commandes de mouvement restent actives 1,5 s puis s'estompent — appuyer
plusieurs fois maintient le mouvement. Par confort de démo, une commande de
mouvement reçue au sol déclenche un décollage automatique.

### Télémétrie (simulateur → Flutter, toutes les 100 ms)

```json
{
  "type": "telemetry",
  "connected": true,
  "state": "Flying",
  "battery": 92,
  "altitude": 5.3,
  "speed": 2.1,
  "yaw": 45,
  "pitch": 0,
  "roll": 0,
  "latitude": 36.8123,
  "longitude": 10.1765,
  "timestamp": 1719900000000
}
```

`state` ∈ `Idle` | `Flying` | `Landing` | `Stopped`.

Les commandes reçoivent un accusé : `{"type": "ack", "command": "UP",
"ok": true, "message": "..."}` ou `{"type": "error", "message": "..."}`.
Chaque commande acceptée est aussi diffusée à **tous** les clients
(`{"type": "command", "command": "UP", "ok": true, "message": "...",
"timestamp": ...}`) — c'est ce qui permet à la vue web d'afficher les
commandes envoyées par l'app mobile.

### Parcelles agricoles (app mobile → simulateur)

À la connexion, l'app mobile envoie les régions de l'utilisateur
(récupérées via `GET /regions` du backend, avec son JWT) :

```json
{ "type": "regions", "regions": [
  { "name": "Oliveraie Nord", "hectares": 2.4, "color": 4283215696,
    "points": [{ "lat": 36.7495, "lng": 10.0490 }, ...] }
] }
```

Le simulateur les met en cache, les rediffuse à tous les spectateurs
(y compris ceux qui se connectent après), et **place le drone au
centroïde de la première parcelle** (uniquement s'il est au sol). La vue
web dessine alors les polygones — remplissage translucide, contour,
étiquette nom + hectares — sur le sol satellite 3D et la vue du dessus,
recentrés sur la zone réelle de la parcelle.

## Simulation

- boucle de mise à jour toutes les **100 ms** ;
- vitesses lissées (accélération bornée) → mouvement fluide, pas instantané ;
- batterie qui se décharge progressivement (plus vite en vol) ;
  à 0 % le drone atterrit automatiquement ;
- position GPS intégrée en lat/lng réels (départ : Tunis 36.8123, 10.1765) ;
- pitch/roll cosmétiques proportionnels aux vitesses.

## Structure

```
drone_simulator/
├── server/
│   └── websocket_server.js   # serveur http+ws, diffusion télémétrie
├── core/
│   ├── drone_simulator.js    # logique : boucle 100 ms, physique, autopilote
│   ├── drone_state.js        # état du drone + payload télémétrie
│   └── command_handler.js    # parsing/validation des commandes
├── utils/
│   └── math_utils.js         # clamp, lissage, conversions GPS
├── web/
│   └── index.html            # vue du drone en direct (spectateur)
└── README.md
```

## Test rapide sans Flutter

```bash
npx wscat -c ws://localhost:8080
> TAKEOFF
> {"command":"FORWARD","speed":3}
> RETURN_HOME
```
