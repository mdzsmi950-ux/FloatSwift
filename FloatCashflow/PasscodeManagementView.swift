import SwiftUI

struct PasscodeManagementView: View {
    @Environment(\.dismiss) private var dismiss

    var mode: PasscodeFlow
    @ObservedObject var privacyLock: PrivacyLockStore

    @State private var currentPasscode = ""
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var errorText: String?
    @State private var activeField: PasscodeEntryField = .new

    var body: some View {
        NativePasscodeScaffold {
            VStack(spacing: 14) {
                Text(promptTitle)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.floatText)
                    .multilineTextAlignment(.center)

                PasscodeDots(count: activePasscode.count, hasError: errorText != nil)

                Text(errorText ?? promptHint)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(errorText == nil ? Color.floatTextMid : Color.floatWarning)
                    .multilineTextAlignment(.center)
                    .frame(height: 18)
            }
            .padding(.top, 42)
        } keypad: {
            NativePasscodeKeypad(
                leftTitle: "Cancel",
                rightTitle: activePasscode.isEmpty ? "" : "Delete",
                onDigit: appendDigit,
                onLeft: { dismiss() },
                onRight: {
                    deleteDigit()
                },
                onDelete: deleteDigit
            )
        }
        .onAppear {
            activeField = needsCurrentPasscode ? .current : .new
        }
    }

    private var title: String {
        switch mode {
        case .setup: "Set Passcode"
        case .change: "Change Passcode"
        case .disable: "Turn Off App Lock"
        }
    }

    private var needsCurrentPasscode: Bool {
        mode == .change || mode == .disable
    }

    private var promptTitle: String {
        switch activeField {
        case .current:
            return mode == .disable ? "Enter Passcode\nto Turn Off App Lock" : "Enter Old Passcode"
        case .new:
            return "Enter New Passcode"
        case .confirm:
            return "Verify New Passcode"
        }
    }

    private var promptHint: String {
        switch activeField {
        case .current:
            return " "
        case .new:
            return "Use 4 digits."
        case .confirm:
            return "Enter the same passcode again."
        }
    }

    private var activePasscode: String {
        switch activeField {
        case .current:
            return currentPasscode
        case .new:
            return newPasscode
        case .confirm:
            return confirmPasscode
        }
    }

    private func confirm() {
        switch activeField {
        case .current:
            confirmCurrentPasscode()
        case .new:
            confirmNewPasscode()
        case .confirm:
            confirmRepeatedPasscode()
        }
    }

    private func confirmCurrentPasscode() {
        guard privacyLock.validatePasscode(currentPasscode) else {
            errorText = "Current passcode is incorrect."
            currentPasscode = ""
            return
        }

        if mode == .disable {
            privacyLock.setEnabled(false)
            dismiss()
            return
        }

        errorText = nil
        activeField = .new
    }

    private func confirmNewPasscode() {
        guard newPasscode.count == 4 else {
            errorText = "Use 4 digits."
            newPasscode = ""
            return
        }

        errorText = nil
        activeField = .confirm
    }

    private func confirmRepeatedPasscode() {
        guard newPasscode == confirmPasscode else {
            errorText = "New passcodes do not match."
            confirmPasscode = ""
            return
        }

        privacyLock.setPasscode(newPasscode)
        privacyLock.setEnabled(true)
        dismiss()
    }

    private func appendDigit(_ digit: String) {
        errorText = nil
        switch activeField {
        case .current:
            guard currentPasscode.count < 4 else { return }
            currentPasscode.append(digit)
            if currentPasscode.count == 4 {
                confirmCurrentPasscode()
            }
        case .new:
            guard newPasscode.count < 4 else { return }
            newPasscode.append(digit)
            if newPasscode.count == 4 {
                confirmNewPasscode()
            }
        case .confirm:
            guard confirmPasscode.count < 4 else { return }
            confirmPasscode.append(digit)
            if confirmPasscode.count == 4 {
                confirmRepeatedPasscode()
            }
        }
    }

    private func deleteDigit() {
        switch activeField {
        case .current:
            guard !currentPasscode.isEmpty else { return }
            currentPasscode.removeLast()
        case .new:
            guard !newPasscode.isEmpty else { return }
            newPasscode.removeLast()
        case .confirm:
            guard !confirmPasscode.isEmpty else { return }
            confirmPasscode.removeLast()
        }
    }
}
