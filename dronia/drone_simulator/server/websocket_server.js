import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';
import { DroneSimulator } from '../core/drone_simulator.js';
import { CommandHandler } from '../core/command_handler.js';

const PORT = Number(process.env.PORT ?? 8080);
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const WEB_DIR = join(ROOT, 'web');
// Vrai modèle 3D de drone DJI, partagé avec l'app Flutter.
const DRONE_MODEL = join(ROOT, '..', 'assets', 'Drones', 'dji_drone_dji_drone.glb');

const simulator = new DroneSimulator();
const commandHandler = new CommandHandler(simulator);

// Serveur HTTP : sert la vue web du drone (web/index.html) et le modèle 3D.
// Les connexions WebSocket passent par le même port via l'upgrade HTTP.
const httpServer = createServer(async (req, res) => {
  if (req.method !== 'GET') {
    res.writeHead(405).end();
    return;
  }
  if (req.url === '/' || req.url === '/index.html') {
    try {
      const html = await readFile(join(WEB_DIR, 'index.html'));
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(html);
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end(`Vue du drone indisponible : ${err.message}`);
    }
    return;
  }
  if (req.url === '/drone.glb') {
    const stream = createReadStream(DRONE_MODEL);
    stream.on('error', () => {
      res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('Modèle 3D introuvable');
    });
    stream.once('open', () => {
      res.writeHead(200, {
        'Content-Type': 'model/gltf-binary',
        'Cache-Control': 'public, max-age=86400',
      });
      stream.pipe(res);
    });
    return;
  }
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Not found');
});

const wss = new WebSocketServer({ server: httpServer });

// Parcelles agricoles envoyées par l'app mobile (GET /regions côté app,
// puis {type:'regions', ...} sur le WebSocket). Conservées pour les
// spectateurs qui se connectent plus tard.
let savedRegions = null;

function broadcast(message) {
  const payload = JSON.stringify(message);
  for (const client of wss.clients) {
    if (client.readyState === client.OPEN) client.send(payload);
  }
}

// Diffuse la télémétrie (toutes les 100 ms) à tous les clients connectés.
simulator.on('telemetry', (telemetry) => broadcast(telemetry));

/** Centroïde d'une liste de points {lat, lng}. */
function centroid(points) {
  const sum = points.reduce(
    (acc, p) => ({ lat: acc.lat + p.lat, lng: acc.lng + p.lng }),
    { lat: 0, lng: 0 },
  );
  return { lat: sum.lat / points.length, lng: sum.lng / points.length };
}

/** Réception des parcelles : cache, diffusion, drone placé sur la 1re. */
function handleRegions(msg) {
  const regions = Array.isArray(msg.regions) ? msg.regions : [];
  savedRegions = regions;
  console.log(`[map] ${regions.length} parcelle(s) reçue(s) de l'app mobile`);
  if (regions.length > 0 && regions[0].points?.length >= 3) {
    const c = centroid(regions[0].points);
    const moved = simulator.setHome(c.lat, c.lng);
    if (moved.ok) {
      console.log(`[map] Drone placé sur « ${regions[0].name} » (${c.lat.toFixed(5)}, ${c.lng.toFixed(5)})`);
    }
  }
  broadcast({ type: 'regions', regions, timestamp: Date.now() });
  return { type: 'ack', command: 'REGIONS', ok: true, message: `${regions.length} parcelle(s) affichée(s)` };
}

wss.on('connection', (socket, request) => {
  console.log(`[+] Client connecté (${request.socket.remoteAddress})`);

  // État courant envoyé immédiatement, sans attendre le prochain tick,
  // suivi des parcelles déjà connues.
  socket.send(JSON.stringify(simulator.state.toTelemetry()));
  if (savedRegions?.length) {
    socket.send(JSON.stringify({ type: 'regions', regions: savedRegions }));
  }

  socket.on('message', (raw) => {
    // Message de données (parcelles) plutôt que commande de pilotage ?
    const text = raw.toString();
    if (text.startsWith('{') && text.includes('"regions"')) {
      try {
        const msg = JSON.parse(text);
        if (msg.type === 'regions') {
          socket.send(JSON.stringify(handleRegions(msg)));
          return;
        }
      } catch { /* traité comme commande ci-dessous */ }
    }

    const response = commandHandler.handle(raw);
    const label = response.command ?? text.slice(0, 40);
    console.log(`[cmd] ${label} → ${response.message}`);
    // Accusé de réception à l'émetteur (l'app mobile) …
    socket.send(JSON.stringify(response));
    // … et notification à tous les spectateurs (vue web) qu'une
    // commande a été reçue par le drone.
    if (response.type === 'ack') {
      broadcast({
        type: 'command',
        command: response.command,
        ok: response.ok,
        message: response.message,
        timestamp: Date.now(),
      });
    }
  });

  socket.on('close', () => console.log('[-] Client déconnecté'));
  socket.on('error', (err) => console.error(`[!] Erreur socket : ${err.message}`));
});

simulator.start();

// host 0.0.0.0 : accessible depuis l'émulateur Android (10.0.2.2)
// et depuis un téléphone physique sur le même réseau local.
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`🚁 Simulateur de drone DJI démarré sur ws://localhost:${PORT}`);
  console.log(`   Station de contrôle web : http://localhost:${PORT}`);
  console.log('   Commandes : TAKEOFF, LAND, UP, DOWN, LEFT, RIGHT, FORWARD,');
  console.log('               BACKWARD, ROTATE_LEFT, ROTATE_RIGHT, STOP, RETURN_HOME');
});
