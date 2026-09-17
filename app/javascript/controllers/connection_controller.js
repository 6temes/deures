import { Controller } from '@hotwired/stimulus'

// The app is online only, and a failed submit is held rather than lost: nothing touches the card
// region, so the typed digits and the showing token survive every retry, and the server replays
// the verdict it already recorded for that token rather than grading it twice.
export default class extends Controller {
  static targets = ['overlay']
  static values = { retry: { type: Number, default: 2000 }, slow: { type: Number, default: 1000 } }

  #form = null
  #held = false
  #retryTimer = null
  #slowTimer = null
  #status = null

  connect() {
    window.addEventListener('online', this.#retry)
  }

  disconnect() {
    window.removeEventListener('online', this.#retry)
    clearTimeout(this.#retryTimer)
    clearTimeout(this.#slowTimer)
  }

  // A dropped Wi-Fi connection does not reject until iOS exhausts its own timeout, and with the
  // progress bar deliberately removed the screen sits completely still until then. A six-year-old
  // cannot tell thinking from broken, so a slow submit gets the same overlay a failed one gets.
  waiting(event) {
    this.#form = event.target
    this.#status = null
    clearTimeout(this.#retryTimer)
    this.#slowTimer = setTimeout(() => this.#show(), this.slowValue)
  }

  // Left alone, Turbo renders a failed response as a full page, which would wipe the typed digits
  // and the showing token the retry has to carry back. This runs for a response and nothing else,
  // so it is also how a server that answered is told apart from one that was never reached.
  inspect(event) {
    this.#status = event.detail.fetchResponse.statusCode
    if (!event.detail.fetchResponse.succeeded) event.preventDefault()
  }

  settled(event) {
    clearTimeout(this.#slowTimer)
    this.#held = !event.detail.success
    if (!this.#held) return this.#hide()
    // A refusal is the server's answer to this request rather than a connection that failed:
    // the same body sent again can never clear it, and the page cannot mint the token that
    // would. Reloading the root renders whatever the child's state now is, which is the one
    // recovery that needs nothing tapped. A server error and a lost connection both still hold.
    if (this.#refused) return window.location.replace('/')

    this.#show()
    this.#retryTimer = setTimeout(this.#retry, this.retryValue)
  }

  get #refused() {
    return this.#status >= 400 && this.#status < 500
  }

  // The next attempt is armed before this one is made, because a submission the form prevents
  // starts nothing and settles nothing, and settled() is the only other place that schedules a
  // retry. waiting() clears this timer whenever a submission does start, which is what keeps one
  // request in flight at a time.
  #retry = () => {
    clearTimeout(this.#retryTimer)
    if (!this.#held) return

    this.#retryTimer = setTimeout(this.#retry, this.retryValue)
    this.#form.requestSubmit()
  }

  #show() {
    this.overlayTarget.hidden = false
  }

  #hide() {
    this.overlayTarget.hidden = true
  }
}
