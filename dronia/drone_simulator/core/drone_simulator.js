import { EventEmitter } from 'node:events';
import { DroneState, DroneStatus } from './drone_state.js';
import {
  approach,
  bearingDegrees,
  clamp,
  degToRad,
  distanceMeters,
  metersToLatLng,
  wrapDegrees,
} from '../utils/math_utils.js';

// Boucle de simulation
const TICK_MS = 100; // mise à jour toutes les 100 ms
const DT = TICK_MS / 1000; // pas de temps en secondes

// Dynamique du drone virtuel
const TAKEOFF_ALTITUDE = 5; // m — altitude cible après décollage
const CLIMB_SPEED = 1.5; // m/s — montée automatique (décollage)
const LAND_SPEED = 1.2; // m/s — descente automatique (atterrissage)
const DEFAULT_MOVE_SPEED = 2; // m/s — vitesse par défaut des commandes
const DEFAULT_YAW_RATE = 45; // deg/s — rotation par défaut
const MAX_SPEED = 8; // m/s — borne des vitesses commandées
const ACCEL = 4; // m/s² — lissage (mouvement fluide, pas instantané)
const YAW_ACCEL = 120; // deg/s² — lissage de la rotation
const COMMAND_HOLD_MS = 1500; // durée d'effet d'une commande de mouvement
const RETURN_SPEED = 3; // m/s — vitesse du retour au point de départ
const BATTERY_DRAIN_FLYING = 0.05; // %/s en vol
const BATTERY_DRAIN_IDLE = 0.005; // %/s au sol
const MAX_TILT = 12; // deg — inclinaison visuelle max (pitch/roll)

// Modes de pilotage automatique internes
const Mode = {
  MANUAL: 'manual',
  TAKEOFF: 'takeoff',
  LANDING: 'landing',
  RETURN: 'return',
};

/**
 * Drone virtuel : logique + état.
 *
 * Émet un événement `telemetry` toutes les 100 ms avec la charge utile
 * JSON destinée à l'application Flutter. Les commandes (takeoff, move,
 * rotate, …) fixent des vitesses cibles ; la boucle `#tick` lisse les
 * vitesses réelles vers ces cibles pour un mouvement fluide.
 */
export class DroneSimulator extends EventEmitter {
  constructor(options = {}) {
    super();
    this.state = new DroneState(options);
    this.#resetMotion();
    this._mode = Mode.MANUAL;
    this._interval = null;
  }

  #resetMotion() {
    // Vitesses réelles (lissées) et cibles, dans le repère du drone.
    this._vz = 0; // vertical (m/s, + = monte)
    this._vForward = 0; // avant/arrière (m/s)
    this._vRight = 0; // latéral (m/s, + = droite)
    this._yawRate = 0; // rotation (deg/s, + = horaire)
    this._vzTarget = 0;
    this._vForwardTarget = 0;
    this._vRightTarget = 0;
    this._yawRateTarget = 0;
    // Échéance de chaque commande de mouvement (0 = aucune).
    this._vzUntil = 0;
    this._vForwardUntil = 0;
    this._vRightUntil = 0;
    this._yawUntil = 0;
  }

  /** Démarre la boucle de simulation temps réel. */
  start() {
    if (this._interval) return;
    this._interval = setInterval(() => this.#tick(), TICK_MS);
  }

  stopLoop() {
    clearInterval(this._interval);
    this._interval = null;
  }

  // ── Commandes ────────────────────────────────────────────────────────

  takeoff() {
    const s = this.state;
    if (s.battery <= 1) {
      return { ok: false, message: 'Batterie insuffisante pour décoller' };
    }
    if (s.status === DroneStatus.FLYING && this._mode !== Mode.LANDING) {
      return { ok: false, message: 'Le drone est déjà en vol' };
    }
    // Le décollage part du point courant, qui devient le nouveau "home".
    if (s.altitude <= 0) {
      s.homeLatitude = s.latitude;
      s.homeLongitude = s.longitude;
      s.altitude = 1; // l'altitude passe à 1 puis augmente progressivement
    }
    s.status = DroneStatus.FLYING;
    this._mode = Mode.TAKEOFF;
    return { ok: true, message: 'Décollage en cours' };
  }

  land() {
    const s = this.state;
    if (s.altitude <= 0) {
      return { ok: false, message: 'Le drone est déjà au sol' };
    }
    s.status = DroneStatus.LANDING;
    this._mode = Mode.LANDING;
    this.#zeroTargets();
    return { ok: true, message: 'Atterrissage en cours' };
  }

  /** Arrête tout mouvement (le drone reste en vol stationnaire). */
  stop() {
    const s = this.state;
    this._mode = Mode.MANUAL;
    this.#zeroTargets();
    this._vz = this._vForward = this._vRight = this._yawRate = 0;
    s.status = s.altitude > 0 ? DroneStatus.STOPPED : DroneStatus.IDLE;
    return { ok: true, message: 'Mouvement arrêté' };
  }

  /**
   * Mouvement sur un axe : 'up', 'down', 'forward', 'backward',
   * 'left', 'right'. La commande reste active COMMAND_HOLD_MS.
   * Par confort de démo, un drone au sol décolle automatiquement.
   */
  move(axis, speed = DEFAULT_MOVE_SPEED) {
    const grounded = this.state.altitude <= 0;
    if (grounded && axis !== 'down') this.takeoff();
    if (grounded && axis === 'down') {
      return { ok: false, message: 'Le drone est déjà au sol' };
    }
    this.state.status = DroneStatus.FLYING;
    if (this._mode !== Mode.TAKEOFF) this._mode = Mode.MANUAL;

    const v = clamp(Math.abs(speed) || DEFAULT_MOVE_SPEED, 0.5, MAX_SPEED);
    const until = Date.now() + COMMAND_HOLD_MS;
    switch (axis) {
      case 'up':
        this._vzTarget = v;
        this._vzUntil = until;
        break;
      case 'down':
        this._vzTarget = -v;
        this._vzUntil = until;
        break;
      case 'forward':
        this._vForwardTarget = v;
        this._vForwardUntil = until;
        break;
      case 'backward':
        this._vForwardTarget = -v;
        this._vForwardUntil = until;
        break;
      case 'right':
        this._vRightTarget = v;
        this._vRightUntil = until;
        break;
      case 'left':
        this._vRightTarget = -v;
        this._vRightUntil = until;
        break;
      default:
        return { ok: false, message: `Axe inconnu : ${axis}` };
    }
    return { ok: true, message: `Mouvement ${axis} (${v} m/s)` };
  }

  /** Rotation : direction -1 (gauche) ou +1 (droite). */
  rotate(direction, rate = DEFAULT_YAW_RATE) {
    if (this.state.altitude <= 0) {
      return { ok: false, message: 'Le drone doit être en vol pour pivoter' };
    }
    const r = clamp(Math.abs(rate) || DEFAULT_YAW_RATE, 10, 180);
    this._yawRateTarget = direction * r;
    this._yawUntil = Date.now() + COMMAND_HOLD_MS;
    return {
      ok: true,
      message: `Rotation ${direction < 0 ? 'gauche' : 'droite'} (${r}°/s)`,
    };
  }

  /**
   * Déplace le drone (au sol uniquement) vers une nouvelle position de
   * départ — utilisé pour placer le drone sur une parcelle de l'utilisateur.
   */
  setHome(latitude, longitude) {
    const s = this.state;
    if (s.altitude > 0) {
      return { ok: false, message: 'Impossible de déplacer le drone en vol' };
    }
    s.latitude = latitude;
    s.longitude = longitude;
    s.homeLatitude = latitude;
    s.homeLongitude = longitude;
    return { ok: true, message: 'Position de départ mise à jour' };
  }

  /** Retour automatique au point de décollage, puis atterrissage. */
  returnHome() {
    const s = this.state;
    if (s.altitude <= 0) {
      return { ok: false, message: 'Le drone est déjà au sol' };
    }
    s.status = DroneStatus.FLYING;
    this._mode = Mode.RETURN;
    this.#zeroTargets();
    return { ok: true, message: 'Retour au point de départ' };
  }

  // ── Boucle de simulation ─────────────────────────────────────────────

  #zeroTargets() {
    this._vzTarget = this._vForwardTarget = this._vRightTarget = 0;
    this._yawRateTarget = 0;
    this._vzUntil = this._vForwardUntil = this._vRightUntil = this._yawUntil = 0;
  }

  #tick() {
    const s = this.state;
    const now = Date.now();
    const airborne = s.altitude > 0;

    // Batterie : décharge progressive, atterrissage forcé à 0 %.
    s.battery = clamp(
      s.battery - (airborne ? BATTERY_DRAIN_FLYING : BATTERY_DRAIN_IDLE) * DT,
      0,
      100,
    );
    if (airborne && s.battery <= 0 && this._mode !== Mode.LANDING) {
      this.land();
    }

    // Pilotage automatique (décollage / atterrissage / retour maison).
    switch (this._mode) {
      case Mode.TAKEOFF:
        this._vzTarget = CLIMB_SPEED;
        this._vzUntil = 0;
        if (s.altitude >= TAKEOFF_ALTITUDE) {
          this._vzTarget = 0;
          this._mode = Mode.MANUAL;
        }
        break;
      case Mode.LANDING:
        this._vzTarget = -LAND_SPEED;
        this._vzUntil = 0;
        break;
      case Mode.RETURN: {
        const dist = distanceMeters(
          s.latitude,
          s.longitude,
          s.homeLatitude,
          s.homeLongitude,
        );
        if (dist < 0.5) {
          this.land();
        } else {
          // Oriente le nez vers "home" puis avance.
          const bearing = bearingDegrees(
            s.latitude,
            s.longitude,
            s.homeLatitude,
            s.homeLongitude,
          );
          let diff = wrapDegrees(bearing - s.yaw);
          if (diff > 180) diff -= 360;
          this._yawRateTarget = clamp(diff * 3, -90, 90);
          // N'avance que nez aligné, sinon le drone orbite autour du point.
          const aligned = Math.max(0, Math.cos(degToRad(diff)));
          this._vForwardTarget = Math.min(RETURN_SPEED, dist) * aligned;
          this._vzTarget = 0;
        }
        break;
      }
      default:
        // Mode manuel : les commandes expirent après COMMAND_HOLD_MS.
        if (this._vzUntil && now > this._vzUntil) this._vzTarget = 0;
        if (this._vForwardUntil && now > this._vForwardUntil) {
          this._vForwardTarget = 0;
        }
        if (this._vRightUntil && now > this._vRightUntil) this._vRightTarget = 0;
        if (this._yawUntil && now > this._yawUntil) this._yawRateTarget = 0;
    }

    // Lissage des vitesses vers leurs cibles (mouvement fluide).
    this._vz = approach(this._vz, this._vzTarget, ACCEL * DT);
    this._vForward = approach(this._vForward, this._vForwardTarget, ACCEL * DT);
    this._vRight = approach(this._vRight, this._vRightTarget, ACCEL * DT);
    this._yawRate = approach(this._yawRate, this._yawRateTarget, YAW_ACCEL * DT);

    // Intégration : cap, altitude, position GPS.
    s.yaw = wrapDegrees(s.yaw + this._yawRate * DT);
    s.altitude = Math.max(0, s.altitude + this._vz * DT);

    const yawRad = degToRad(s.yaw);
    const vEast = this._vForward * Math.sin(yawRad) + this._vRight * Math.cos(yawRad);
    const vNorth = this._vForward * Math.cos(yawRad) - this._vRight * Math.sin(yawRad);
    const { dLat, dLng } = metersToLatLng(vNorth * DT, vEast * DT, s.latitude);
    s.latitude += dLat;
    s.longitude += dLng;
    s.speed = Math.hypot(vEast, vNorth);

    // Inclinaison cosmétique proportionnelle aux vitesses.
    s.pitch = clamp(-this._vForward * 3, -MAX_TILT, MAX_TILT);
    s.roll = clamp(this._vRight * 3, -MAX_TILT, MAX_TILT);

    // Fin d'atterrissage : le drone touche le sol.
    if (this._mode === Mode.LANDING && s.altitude <= 0) {
      this._mode = Mode.MANUAL;
      this.#zeroTargets();
      this._vz = this._vForward = this._vRight = this._yawRate = 0;
      s.altitude = 0;
      s.speed = 0;
      s.pitch = 0;
      s.roll = 0;
      s.status = DroneStatus.IDLE;
    }

    this.emit('telemetry', s.toTelemetry());
  }
}
