import { round } from '../utils/math_utils.js';

/** États possibles du drone virtuel (alignés sur le cycle de vie DJI). */
export const DroneStatus = {
  IDLE: 'Idle',
  FLYING: 'Flying',
  LANDING: 'Landing',
  STOPPED: 'Stopped',
};

/**
 * État du drone virtuel — uniquement des données.
 * La logique de mise à jour vit dans `DroneSimulator`.
 */
export class DroneState {
  constructor({ latitude = 36.8123, longitude = 10.1765 } = {}) {
    this.status = DroneStatus.IDLE;
    this.altitude = 0; // m
    this.latitude = latitude;
    this.longitude = longitude;
    this.speed = 0; // m/s (horizontale)
    this.yaw = 0; // deg [0, 360), 0 = nord
    this.pitch = 0; // deg
    this.roll = 0; // deg
    this.battery = 100; // %

    // Point de départ mémorisé pour RETURN_HOME.
    this.homeLatitude = latitude;
    this.homeLongitude = longitude;
  }

  /** Charge utile de télémétrie envoyée à l'application Flutter. */
  toTelemetry() {
    return {
      type: 'telemetry',
      connected: true,
      state: this.status,
      battery: Math.round(this.battery),
      altitude: round(this.altitude, 1),
      speed: round(this.speed, 1),
      yaw: Math.round(this.yaw),
      pitch: round(this.pitch, 1),
      roll: round(this.roll, 1),
      latitude: round(this.latitude, 6),
      longitude: round(this.longitude, 6),
      timestamp: Date.now(),
    };
  }
}
