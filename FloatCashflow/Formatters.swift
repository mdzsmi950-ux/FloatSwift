import Foundation
import SwiftUI

extension Date {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static var todayString: String {
        Date().ymdString
    }

    var ymdString: String {
        Date.yyyyMMdd.string(from: self)
    }
}

func money(_ amount: Double) -> String {
    amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
}

func signedMoney(_ amount: Double) -> String {
    let prefix = amount >= 0 ? "+" : "-"
    return "\(prefix)\(money(abs(amount)))"
}

func labelDate(_ value: String) -> String {
    guard let date = Date.yyyyMMdd.date(from: value) else { return value }
    let calendar = Calendar(identifier: .gregorian)
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    guard let month = components.month, let day = components.day else { return value }

    if let year = components.year, year >= 2027 {
        return "\(month)/\(day)/\(year)"
    }

    return "\(month)/\(day)"
}

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8) & 0xff) / 255
        let b = Double(int & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }

    static let floatText = Color(hex: "1A1A1A")
    static let floatTextMid = Color(hex: "555555")
    static let floatTextSubtle = Color(hex: "888888")
    static let floatTextFaint = Color(hex: "AAAAAA")
    static let floatBorder = Color(hex: "E0E0E0")
    static let floatDivider = Color(hex: "F0F0F0")
    static let floatSubtle = Color(hex: "F5F5F5")
    static let floatAccent = Color(hex: "3A6B4A")
    static let floatDanger = Color(hex: "8B4060")
    static let floatWarning = Color(hex: "C0392B")
}

struct SettingsHeader: View {
    var title: String
    var open: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(open ? "▾" : "▸")
                    .font(.system(size: 14, weight: .semibold))
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1)
                Spacer()
            }
            .foregroundStyle(Color.floatTextFaint)
        }
        .buttonStyle(.plain)
    }
}

struct FloatTextField: View {
    var placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboard)
            .font(.system(size: 14))
            .foregroundStyle(Color.floatText)
            .tint(Color.floatText)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.floatBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FloatButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Color.floatText)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color.floatSubtle)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.floatBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
