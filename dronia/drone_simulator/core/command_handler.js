/** Commandes acceptées par le simulateur. */
export const SUPPORTED_COMMANDS = [
  'TAKEOFF',
  'LAND',
  'UP',
  'DOWN',
  'LEFT',
  'RIGHT',
  'FORWARD',
  'BACKWARD',
  'ROTATE_LEFT',
  'ROTATE_RIGHT',
  'STOP',
  'RETURN_HOME',
];

/**
 * Traduit les messages WebSocket bruts en appels sur le simulateur.
 *
 * Deux formats sont acceptés :
 *   - texte brut :  UP
 *   - JSON       :  {"command": "UP", "speed": 2}
 *
 * Retourne toujours une réponse sérialisable :
 *   {type: 'ack', command, ok, message}  ou  {type: 'error', message}
 */
export class CommandHandler {
  constructor(simulator) {
    this.simulator = simulator;
  }

  handle(raw) {
    const text = raw.toString().trim();
    let command = text;
    let speed;

    if (text.startsWith('{')) {
      try {
        const parsed = JSON.parse(text);
        command = String(parsed.command ?? '');
        if (typeof parsed.speed === 'number') speed = parsed.speed;
      } catch {
        return { type: 'error', message: 'Message JSON invalide' };
      }
    }
    command = command.toUpperCase();

    if (!SUPPORTED_COMMANDS.includes(command)) {
      return { type: 'error', message: `Commande inconnue : ${command}` };
    }

    const result = this.#dispatch(command, speed);
    return { type: 'ack', command, ok: result.ok, message: result.message };
  }

  #dispatch(command, speed) {
    const sim = this.simulator;
    switch (command) {
      case 'TAKEOFF':
        return sim.takeoff();
      case 'LAND':
        return sim.land();
      case 'UP':
        return sim.move('up', speed);
      case 'DOWN':
        return sim.move('down', speed);
      case 'FORWARD':
        return sim.move('forward', speed);
      case 'BACKWARD':
        return sim.move('backward', speed);
      case 'LEFT':
        return sim.move('left', speed);
      case 'RIGHT':
        return sim.move('right', speed);
      case 'ROTATE_LEFT':
        return sim.rotate(-1, speed);
      case 'ROTATE_RIGHT':
        return sim.rotate(1, speed);
      case 'STOP':
        return sim.stop();
      case 'RETURN_HOME':
        return sim.returnHome();
      // Inatteignable : la commande est validée en amont.
      default:
        return { ok: false, message: `Commande inconnue : ${command}` };
    }
  }
}
