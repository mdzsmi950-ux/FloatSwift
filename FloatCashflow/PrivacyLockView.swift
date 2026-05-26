import SwiftUI

struct PrivacyLockView: View {
    @ObservedObject var privacyLock: PrivacyLockStore
    @State private var passcode = ""
    @State private var errorText: String?
    @State private var attemptedFaceID = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.floatSubtle, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: privacyLock.faceIDAvailable ? "faceid" : "lock.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.floatTextMid)
                        .frame(width: 62, height: 62)
                        .background(.white.opacity(0.7))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.black.opacity(0.08), lineWidth: 0.5)
                        )

                    Text("Unlock Float")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.floatText)

                    Text(privacyLock.faceIDAvailable ? "Use Face ID or enter your Float passcode." : "Enter your Float passcode.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.floatTextFaint)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 14) {
                    PasscodeDots(count: passcode.count, hasError: errorText != nil)
                    .onChange(of: passcode) {
                        if passcode.count >= 4 {
                            errorText = nil
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.floatWarning)
                            .frame(maxWidth: .infinity)
                    }

                    PasscodeKeypad(
                        onDigit: appendDigit,
                        onDelete: deleteDigit,
                        onConfirm: unlockWithPasscode
                    )

                    if privacyLock.faceIDAvailable {
                        Button {
                            Task { await unlockWithFaceID() }
                        } label: {
                            Label("Use Face ID", systemImage: "faceid")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.floatTextMid)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: 320)

                Spacer()
            }
            .padding(.horizontal, 28)
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
        HStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.floatText : Color.floatTextFaint.opacity(0.18))
                    .overlay(
                        Circle()
                            .stroke(hasError ? Color.floatWarning.opacity(0.8) : Color.floatTextFaint.opacity(0.22), lineWidth: hasError ? 1 : 0.5)
                    )
                    .frame(width: 12, height: 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

struct PasscodeInputRow: View {
    var title: String
    var count: Int
    var isActive: Bool
    var hasError: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? Color.floatText : Color.floatTextMid)

                HStack {
                    PasscodeDots(count: count, hasError: hasError)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(.white.opacity(isActive ? 0.9 : 0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isActive ? Color.floatText.opacity(0.2) : Color.floatBorder, lineWidth: isActive ? 1 : 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct PasscodeKeypad: View {
    var onDigit: (String) -> Void
    var onDelete: () -> Void
    var onConfirm: () -> Void

    private let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["delete", "0", "confirm"]
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 18) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        Button {
            switch key {
            case "delete":
                onDelete()
            case "confirm":
                onConfirm()
            default:
                onDigit(key)
            }
        } label: {
            Group {
                switch key {
                case "delete":
                    Image(systemName: "delete.left")
                        .font(.system(size: 17, weight: .medium))
                case "confirm":
                    Text("OK")
                        .font(.system(size: 14, weight: .semibold))
                default:
                    Text(key)
                        .font(.system(size: 25, weight: .medium))
                }
            }
            .foregroundStyle(Color.floatText)
            .frame(width: 64, height: 48)
            .background(key == "delete" || key == "confirm" ? Color.clear : .white.opacity(0.68))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(key == "delete" || key == "confirm" ? .clear : .black.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: key))
    }

    private func accessibilityLabel(for key: String) -> String {
        switch key {
        case "delete": "Delete"
        case "confirm": "OK"
        default: key
        }
    }
}
