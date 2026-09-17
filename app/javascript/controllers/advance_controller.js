import { Controller } from '@hotwired/stimulus'

// The next card is already rendered underneath, so lifting the overlay is the whole advance.
// The timer is cleared on disconnect, or two fast answers would leave the first overlay's
// timer running over the second one and advance it early.
export default class extends Controller {
  static values = { delay: { type: Number, default: 800 } }

  #timer = null

  connect() {
    this.#timer = setTimeout(() => this.element.remove(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.#timer)
  }
}
