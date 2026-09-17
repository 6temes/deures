import { Controller } from '@hotwired/stimulus'

const LIMIT = 6

// The typed digits live in the DOM, inside the region the server replaces. The controller
// holds no buffer of its own, so the next question arrives empty with nothing to reset.
export default class extends Controller {
  static targets = ['correction', 'expected', 'form', 'submit', 'typed', 'verdict']

  #outstanding = false

  digit(event) {
    event.preventDefault()
    // Stimulus types a numeric param as a number, and the copy compares it against the text
    // of a digit it has rendered.
    const digit = String(event.params.digit ?? event.key)

    if (this.hasCorrectionTarget) return this.#copy(digit)
    if (this.#inert) return

    this.#append(digit)
  }

  backspace(event) {
    event.preventDefault()
    if (this.#inert) return

    this.typedTarget.value = this.#typed.slice(0, -1)
  }

  enter(event) {
    event.preventDefault()
    if (this.#inert) return

    this.formTarget.requestSubmit(this.submitTarget)
  }

  // Preventing the event is what keeps Turbo from sending the request: with nothing typed
  // there is nothing to grade, so nothing may reach the server either. What the card region
  // holds decides this and not #inert, because the retry of a held submit comes back through
  // here while that submit is still outstanding, and preventing it would end the retry loop.
  submit(event) {
    if (this.#covered || this.#typed === '') event.preventDefault()
  }

  started() {
    this.#outstanding = true
  }

  // A submit that failed is still outstanding: its retry carries the same digits and the same
  // showing back, so the answer stays frozen until a verdict lands rather than until the
  // request that failed to fetch one finishes.
  settled(event) {
    if (event.detail.success) this.#outstanding = false
  }

  // Nothing is typed into an answer that has already been sent, and nothing is typed over a
  // card the child has not seen yet.
  get #inert() {
    return this.#outstanding || this.#covered
  }

  // The pad reads the card region the server has just rewritten. It takes nothing while a
  // verdict or a correction is over that region, so the next card underneath cannot be typed
  // into or graded before the child has seen it, and nothing at all once the region holds no
  // answer field. The copy is the one thing a correction does take, and digit() reaches it
  // before this getter.
  get #covered() {
    return this.hasCorrectionTarget || this.hasVerdictTarget || !this.hasTypedTarget
  }

  get #typed() {
    return this.typedTarget.value
  }

  #append(digit) {
    if (this.#typed.length >= LIMIT) return

    this.typedTarget.value = this.#typed + digit
  }

  // Only the digit that comes next is taken, so a mistyped one is impossible rather than
  // handled, and nothing is submitted: the last digit of the copy is what continues.
  #copy(digit) {
    const next = this.expectedTargets.find((span) => !span.hasAttribute('data-copied'))
    if (next?.textContent !== digit) return

    next.setAttribute('data-copied', '')
    if (this.expectedTargets.every((span) => span.hasAttribute('data-copied')))
      this.correctionTarget.remove()
  }
}
