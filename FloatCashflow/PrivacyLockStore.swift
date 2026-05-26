import CryptoKit
import Foundation
import LocalAuthentication

@MainActor
final class PrivacyLockStore: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked = false
    @Published private(set) var faceIDAvailable = false

    private let defaults = UserDefaults.standard
    private let relockGraceInterval: TimeInterval = 60
    private var lastUnlockedExitDate: Date?

    init() {
        isEnabled = defaults.bool(forKey: AppStorageKey.appLockEnabled)
        refreshBiometry()
        if isEnabled, hasPasscode {
            isLocked = true
        }
    }

    var hasPasscode: Bool {
        defaults.string(forKey: AppStorageKey.appLockPasscodeHash) != nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: AppStorageKey.appLockEnabled)
        if !enabled {
            isLocked = false
        }
    }

    func setPasscode(_ passcode: String) {
        let salt = defaults.string(forKey: AppStorageKey.appLockPasscodeSalt) ?? UUID().uuidString
        defaults.set(salt, forKey: AppStorageKey.appLockPasscodeSalt)
        defaults.set(hash(passcode, salt: salt), forKey: AppStorageKey.appLockPasscodeHash)
    }

    func validatePasscode(_ passcode: String) -> Bool {
        guard let salt = defaults.string(forKey: AppStorageKey.appLockPasscodeSalt),
              let storedHash = defaults.string(forKey: AppStorageKey.appLockPasscodeHash) else {
            return false
        }

        return hash(passcode, salt: salt) == storedHash
    }

    func appDidLeaveActive() {
        if isEnabled, hasPasscode, !isLocked {
            lastUnlockedExitDate = Date()
        }
    }

    func lockIfNeededAfterGrace() {
        refreshBiometry()
        guard isEnabled, hasPasscode, !isLocked else { return }
        guard let lastUnlockedExitDate else { return }

        if Date().timeIntervalSince(lastUnlockedExitDate) < relockGraceInterval {
            return
        }

        isLocked = true
    }

    func lockIfNeeded() {
        refreshBiometry()
        if isEnabled, hasPasscode {
            isLocked = true
        }
    }

    func unlockWithPasscode(_ passcode: String) -> Bool {
        guard validatePasscode(passcode) else {
            return false
        }

        isLocked = false
        lastUnlockedExitDate = nil
        return true
    }

    func unlockWithFaceID() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .faceID else {
            refreshBiometry(context: context)
            return false
        }

        do {
            let unlocked = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock Float Cashflow"
            )
            if unlocked {
                isLocked = false
                lastUnlockedExitDate = nil
            }
            refreshBiometry(context: context)
            return unlocked
        } catch {
            refreshBiometry(context: context)
            return false
        }
    }

    private func refreshBiometry(context: LAContext = LAContext()) {
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        faceIDAvailable = context.biometryType == .faceID
    }

    private func hash(_ passcode: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data("\(salt):\(passcode)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
