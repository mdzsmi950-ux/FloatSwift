import SwiftUI

struct PrivacyLockView: View {
    @ObservedObject var privacyLock: PrivacyLockStore
    @State private var passcode = ""
    @State private var errorText: String?
    @State private var attemptedFaceID = false

    var body: some View {
        NativePasscodeScaffold {
            VStack(spacing: 14) {
                Image(systemName: privacyLock.faceIDAvailable ? "faceid" : "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.floatTextMid)
                    .frame(height: 34)

                Text(privacyLock.faceIDAvailable ? "Swipe up for Face ID or\nEnter Passcode" : "Enter Passcode")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.floatText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                PasscodeDots(count: passcode.count, hasError: errorText != nil)

                Text(errorText ?? " ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.floatWarning)
                    .frame(height: 16)
            }
            .padding(.top, 30)
        } keypad: {
            NativePasscodeKeypad(
                leftTitle: privacyLock.faceIDAvailable ? "Face ID" : "",
                rightTitle: passcode.isEmpty ? "" : passcode.count >= 4 ? "OK" : "Delete",
                onDigit: appendDigit,
                onLeft: {
                    Task { await unlockWithFaceID() }
                },
                onRight: {
                    if passcode.count >= 4 {
                        unlockWithPasscode()
                    } else {
                        deleteDigit()
                    }
                },
                onDelete: deleteDigit
            )
        }
        .task {
            guard !attemptedFaceID else { return }
            attemptedFaceID = true
            await unlockWithFaceID()
        }
    }

    private func unlockWithFaceID() async {
        guard privacyLock.faceIDAvailable else { return }
        _ = await privacyLock.unlockWithFaceID()
    }

    private func unlockWithPasscode() {
        guard passcode.count >= 4 else {
            errorText = "Enter your 4 to 6 digit passcode."
            return
        }

        if privacyLock.unlockWithPasscode(passcode) {
            errorText = nil
            passcode = ""
        } else {
            errorText = "Incorrect passcode."
        }
    }

    private func appendDigit(_ digit: String) {
        guard passcode.count < 6 else { return }
        passcode.append(digit)
        errorText = nil
        if passcode.count == 6 {
            unlockWithPasscode()
        }
    }

    private func deleteDigit() {
        guard !passcode.isEmpty else { return }
        passcode.removeLast()
    }
}

struct PasscodeDots: View {
    var count: Int
    var hasError: Bool = false

    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.floatText : .clear)
                    .overlay(
                        Circle()
                            .stroke(hasError ? Color.floatWarning.opacity(0.85) : Color.floatText.opacity(0.32), lineWidth: hasError ? 1.4 : 1.2)
                    )
                    .frame(width: 11, height: 11)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct NativePasscodeScaffold<Prompt: View, Keypad: View>: View {
    @ViewBuilder var prompt: () -> Prompt
    @ViewBuilder var keypad: () -> Keypad

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "E9EEF2"),
                    Color(hex: "D7E2E0"),
                    Color(hex: "EFF0ED")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Color.white.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 42)
                prompt()
                Spacer(minLength: 8)
                keypad()
                    .padding(.bottom, 22)
            }
            .padding(.horizontal, 28)
        }
    }
}

struct NativePasscodeKeypad: View {
    var leftTitle: String
    var rightTitle: String
    var onDigit: (String) -> Void
    var onLeft: () -> Void
    var onRight: () -> Void
    var onDelete: () -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["blank-left", "0", "blank-right"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }

            HStack {
                footerButton(leftTitle, action: onLeft)
                Spacer()
                footerButton(rightTitle, action: onRight)
            }
            .frame(width: 292)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        Button {
            switch key {
            case "blank-left", "blank-right":
                break
            default:
                onDigit(key)
            }
        } label: {
            Group {
                switch key {
                case "blank-left", "blank-right":
                    Color.clear
                default:
                    VStack(spacing: 0) {
                        Text(key)
                            .font(.system(size: 34, weight: .regular))
                        Text(letters(for: key))
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.5)
                            .opacity(letters(for: key).isEmpty ? 0 : 0.85)
                    }
                }
            }
            .foregroundStyle(Color.floatText.opacity(key.hasPrefix("blank") ? 0 : 0.92))
            .frame(width: 78, height: 78)
            .background(key.hasPrefix("blank") ? Color.clear : .white.opacity(0.28))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(key.hasPrefix("blank") ? .clear : .white.opacity(0.28), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(key.hasPrefix("blank"))
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    @ViewBuilder
    private func footerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.floatText.opacity(title.isEmpty ? 0 : 0.88))
                .frame(width: 96, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(title.isEmpty)
    }

    private func letters(for key: String) -> String {
        switch key {
        case "2": "ABC"
        case "3": "DEF"
        case "4": "GHI"
        case "5": "JKL"
        case "6": "MNO"
        case "7": "PQRS"
        case "8": "TUV"
        case "9": "WXYZ"
        default: ""
        }
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "blank-left", "blank-right": ""
        default: key
        }
    }
}
