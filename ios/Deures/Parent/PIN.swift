import CommonCrypto
import Foundation

struct PIN: Equatable {
  let digits: String

  init?(_ digits: String) {
    guard digits.count == 6, digits.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
    self.digits = digits
  }

  // PBKDF2 rather than one SHA-256 pass: a million possible PINs make any fast hash a
  // lookup table, and the stretching is what a copied Keychain item would cost to reverse.
  func hash(salt: Data) -> Data {
    let password = Array(digits.utf8)
    var derived = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    let status = salt.withUnsafeBytes { saltBytes in
      CCKeyDerivationPBKDF(
        CCPBKDFAlgorithm(kCCPBKDF2),
        password.map { CChar(bitPattern: $0) }, password.count,
        saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 100_000,
        &derived, derived.count
      )
    }
    precondition(status == kCCSuccess, "PBKDF2 failed with \(status)")
    return Data(derived)
  }
}
