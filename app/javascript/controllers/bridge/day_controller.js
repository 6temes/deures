import { BridgeComponent } from '@hotwired/hotwire-native-bridge'

// The app listens for this to lift the gate the moment the day ends. Outside the app the
// component never loads: BridgeComponent only registers when the user agent names it.
export default class extends BridgeComponent {
  static component = 'day'
  static values = { childId: Number, date: String }

  connect() {
    super.connect()
    this.send('done', { child_id: this.childIdValue, date: this.dateValue })
  }
}
