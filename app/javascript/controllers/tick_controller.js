import { Controller } from '@hotwired/stimulus'

// An iPad has no vibration motor, so a key's only feedback is what it looks like and what it
// sounds like. pointerdown rather than click, because the sound belongs to the press and not
// to the release, and because it is the gesture iOS wants before it will play anything at all.
export default class extends Controller {
  static values = { src: String }

  #sound

  connect() {
    this.#sound = new Audio(this.srcValue)
    this.#sound.preload = 'auto'
  }

  press(event) {
    if (!event.target.closest('.key')) return

    // Restarting rather than waiting: a child typing fast presses the next key well inside the
    // 55ms the click lasts, and a dropped one would read as a key that did not register.
    this.#sound.currentTime = 0
    this.#sound.play().catch(() => {})
  }
}
