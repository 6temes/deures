import { Controller } from '@hotwired/stimulus'

const COVER = '.verdict, .correction'

// The done screen is rendered underneath the verdict overlay or the correction, the way the
// next card is, so it is in the DOM well before the child can see it: up to the verdict's own
// delay, and for as long as the copy takes. The celebration starts when whatever covers it
// goes, or it would play out unseen.
export default class extends Controller {
  #observer = null

  connect() {
    if (this.#uncovered) return this.#celebrate()

    this.#observer = new MutationObserver(() => {
      if (this.#uncovered) this.#celebrate()
    })
    this.#observer.observe(this.element.parentElement, { childList: true })
  }

  disconnect() {
    this.#observer?.disconnect()
  }

  get #uncovered() {
    return !this.element.parentElement.querySelector(COVER)
  }

  #celebrate() {
    this.#observer?.disconnect()
    this.element.classList.add('celebrating')
  }
}
