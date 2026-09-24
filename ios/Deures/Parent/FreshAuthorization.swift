import FamilyControls

// Proof that a parent has just approved Screen Time on this iPad, the one moment a PIN may
// be replaced without knowing it. It exists only for the move from not-approved to approved.
struct FreshAuthorization {
  init?(from previous: AuthorizationStatus, to current: AuthorizationStatus) {
    guard previous != .approved, current == .approved else { return nil }
  }
}
