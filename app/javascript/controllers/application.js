import { Application } from '@hotwired/stimulus'

const application = Application.start()

// Backspace is not in Stimulus's default key map, and the number pad needs it.
application.schema = {
  ...application.schema,
  keyMappings: { ...application.schema.keyMappings, backspace: 'Backspace' },
}

application.debug = false
window.Stimulus = application

export { application }
