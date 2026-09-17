import { Controller } from '@hotwired/stimulus'

// A page resumed from the app switcher rather than launched cold can be yesterday's, and
// yesterday's screen has nothing on it to tap. The root renders whatever the current state
// is, so reloading it is always safe.
export default class extends Controller {
  static values = { date: String, zone: String }

  #revalidate = () => {
    if (document.visibilityState !== 'visible') return
    if (this.#today() === this.dateValue) return

    window.location.replace('/')
  }

  connect() {
    document.addEventListener('visibilitychange', this.#revalidate)
  }

  disconnect() {
    document.removeEventListener('visibilitychange', this.#revalidate)
  }

  // The household's day, not the iPad's: the server decides which day a card is due on.
  #today() {
    return new Intl.DateTimeFormat('en-CA', { timeZone: this.zoneValue }).format(new Date())
  }
}
