import SwiftUI
import UniformTypeIdentifiers

enum SettingsSection: CaseIterable, Hashable {
    case accounts
    case balance
    case inItems
    case outItems
    case reserve
    case general
    case debtOverview
}

enum SettingsMode {
    case income
    case out
    case settings

    var title: String {
        switch self {
        case .income:
            "In"
        case .out:
            "Out"
        case .settings:
            "Settings"
        }
    }
}

enum PasscodeFlow: Identifiable {
    case setup
    case change
    case disable

    var id: String {
        switch self {
        case .setup: "setup"
        case .change: "change"
        case .disable: "disable"
        }
    }
}

enum PasscodeEntryField {
    case current
    case new
    case confirm
}

enum SetupStep {
    case account
    case balance
    case income
    case outgoingPayment
    case overview

    static let totalSteps = 5

    var number: Int {
        switch self {
        case .account:
            return 1
        case .balance:
            return 2
        case .income:
            return 3
        case .outgoingPayment:
            return 4
        case .overview:
            return 5
        }
    }

    var title: String {
        switch self {
        case .account:
            return "Name the account you use most"
        case .balance:
            return "Confirm your cash balance"
        case .income:
            return "Add your next In"
        case .outgoingPayment:
            return "Add an outgoing payment"
        case .overview:
            return "Check your first Overview"
        }
    }

    var message: String {
        switch self {
        case .account:
            return "Start with the account you actually use for Out items. You can keep the default name or edit it now."
        case .balance:
            return "Enter the money available for Out items and regular payments. Leave out savings and emergency reserves."
        case .income:
            return "Add money coming in. This gives Float the rhythm of when your cash refills."
        case .outgoingPayment:
            return "Add one outgoing payment. Bills, cards, debts, transfers, or other outgoing payments are enough to make Overview useful."
        case .overview:
            return "Your first Overview is ready. Go back to Overview to see whether this account is floating or sinking."
        }
    }
}

enum SettingsSheet: Identifiable {
    case newBill
    case editBill(BudgetBill)
    case newIncome
    case editIncome(BudgetIncome)
    case newAccount
    case editAccount(FloatAccount)

    var id: String {
        switch self {
        case .newBill: "new-bill"
        case .editBill(let bill): "edit-bill-\(bill.id)"
        case .newIncome: "new-income"
        case .editIncome(let income): "edit-income-\(income.id)"
        case .newAccount: "new-account"
        case .editAccount(let account): "edit-account-\(account.id)"
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data("{}".utf8)) {
        self.data = data
    }

    init(budget: FloatBudget) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(budget)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
