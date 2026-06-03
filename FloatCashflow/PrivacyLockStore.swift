import CryptoKit
import Foundation
import LocalAuthentication
import Security

@MainActor
final class PrivacyLockStore: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked = false
    @Published private(set) var faceIDAvailable = false

    private let defaults = UserDefaults.standard
    private let relockGraceInterval: TimeInterval = 60
    private let keychainService = "com.maddie.floatapp.v1.appLock"
    private let passcodeHashAccount = "passcodeHash"
    private let passcodeSaltAccount = "passcodeSalt"
    private var lastUnlockedExitDate: Date?

    init() {
        isEnabled = defaults.bool(forKey: AppStorageKey.appLockEnabled)
        migrateLegacyPasscodeToKeychain()
        refreshBiometry()
        if isEnabled, hasPasscode {
            isLocked = true
        }
    }

    var hasPasscode: Bool {
        keychainString(account: passcodeHashAccount) != nil
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: AppStorageKey.appLockEnabled)
        if !enabled {
            isLocked = false
        }
    }

    func setPasscode(_ passcode: String) {
        let salt = keychainString(account: passcodeSaltAccount) ?? UUID().uuidString
        setKeychainString(salt, account: passcodeSaltAccount)
        setKeychainString(hash(passcode, salt: salt), account: passcodeHashAccount)
    }

    func validatePasscode(_ passcode: String) -> Bool {
        guard let salt = keychainString(account: passcodeSaltAccount),
              let storedHash = keychainString(account: passcodeHashAccount) else {
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

    private func migrateLegacyPasscodeToKeychain() {
        guard keychainString(account: passcodeHashAccount) == nil,
              let legacyHash = defaults.string(forKey: AppStorageKey.appLockPasscodeHash),
              let legacySalt = defaults.string(forKey: AppStorageKey.appLockPasscodeSalt) else {
            return
        }

        setKeychainString(legacySalt, account: passcodeSaltAccount)
        setKeychainString(legacyHash, account: passcodeHashAccount)
        defaults.removeObject(forKey: AppStorageKey.appLockPasscodeSalt)
        defaults.removeObject(forKey: AppStorageKey.appLockPasscodeHash)
    }

    private func keychainString(account: String) -> String? {
        var query = keychainQuery(account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func setKeychainString(_ value: String, account: String) -> Bool {
        deleteKeychainString(account: account)

        var item = keychainQuery(account: account)
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    private func deleteKeychainString(account: String) {
        SecItemDelete(keychainQuery(account: account) as CFDictionary)
    }

    private func keychainQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
    }
}
