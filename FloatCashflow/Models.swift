import Foundation

enum Frequency: String, Codable, CaseIterable, Identifiable {
    case oneTime = "one-time"
    case weekly
    case biweekly
    case monthly
    case quarterly
    case semiannual
    case annual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneTime: "One-time"
        case .weekly: "Weekly"
        case .biweekly: "Every two weeks"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .semiannual: "Every six months"
        case .annual: "Annual"
        }
    }
}

struct PaidEarlyBill: Codable, Identifiable, Equatable {
    var id: String
    var billId: String
    var originalDate: String
    var paidDate: String
    var amount: Double
}

struct BudgetBill: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var amount: Double
    var startDate: String
    var frequency: Frequency
    var active: Bool
    var linkedTransferId: String?
    var debtDetails: BudgetDebtDetails? = nil
}

struct BudgetDebtDetails: Codable, Equatable {
    var startingBalance: Double
    var currentPrincipal: Double
    var accruedInterest: Double
    var balanceDate: String
    var interestRateAPR: Double
    var minimumPayment: Double

    var estimatedCurrentBalance: Double {
        currentPrincipal + accruedInterest
    }
}

struct BudgetIncome: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var amount: Double
    var startDate: String
    var frequency: Frequency
    var active: Bool
    var linkedTransferId: String?
}

struct FloatAccount: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var color: String
    var currentBalance: Double
    var reserveBalance: Double
    var reserveGoal: Double
    var lastConfirmedDate: String?
    var bills: [BudgetBill]
    var income: [BudgetIncome]
    var paidEarlyBills: [PaidEarlyBill]
    var appliedReserveTransfers: [String]
    var balanceIsConfirmed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case currentBalance
        case reserveBalance
        case reserveGoal
        case lastConfirmedDate
        case bills
        case income
        case paidEarlyBills
        case appliedReserveTransfers
        case balanceIsConfirmed
    }

    init(
        id: String,
        name: String,
        color: String,
        currentBalance: Double,
        reserveBalance: Double,
        reserveGoal: Double,
        lastConfirmedDate: String?,
        bills: [BudgetBill],
        income: [BudgetIncome],
        paidEarlyBills: [PaidEarlyBill],
        appliedReserveTransfers: [String],
        balanceIsConfirmed: Bool
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.currentBalance = currentBalance
        self.reserveBalance = reserveBalance
        self.reserveGoal = reserveGoal
        self.lastConfirmedDate = lastConfirmedDate
        self.bills = bills
        self.income = income
        self.paidEarlyBills = paidEarlyBills
        self.appliedReserveTransfers = appliedReserveTransfers
        self.balanceIsConfirmed = balanceIsConfirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "EEE9E7"
        currentBalance = try container.decode(Double.self, forKey: .currentBalance)
        reserveBalance = try container.decode(Double.self, forKey: .reserveBalance)
        reserveGoal = try container.decode(Double.self, forKey: .reserveGoal)
        lastConfirmedDate = try container.decodeIfPresent(String.self, forKey: .lastConfirmedDate)
        bills = try container.decodeIfPresent([BudgetBill].self, forKey: .bills) ?? []
        income = try container.decodeIfPresent([BudgetIncome].self, forKey: .income) ?? []
        paidEarlyBills = try container.decodeIfPresent([PaidEarlyBill].self, forKey: .paidEarlyBills) ?? []
        appliedReserveTransfers = try container.decodeIfPresent([String].self, forKey: .appliedReserveTransfers) ?? []
        balanceIsConfirmed = try container.decodeIfPresent(Bool.self, forKey: .balanceIsConfirmed) ?? true
    }
}

struct FloatBudget: Codable, Equatable {
    var version: Int
    var activeAccountId: String
    var accounts: [FloatAccount]

    var activeAccount: FloatAccount? {
        accounts.first { $0.id == activeAccountId } ?? accounts.first
    }
}

struct CashEvent: Identifiable, Equatable {
    enum EventType {
        case bill
        case income
    }

    var id: String
    var type: EventType
    var label: String
    var amount: Double
    var date: String
}

extension FloatBudget {
    static let blank = FloatBudget(
        version: 1,
        activeAccountId: "personal",
        accounts: [
            FloatAccount(
                id: "personal",
                name: "Personal",
                color: "EEE9E7",
                currentBalance: 0,
                reserveBalance: 0,
                reserveGoal: 0,
                lastConfirmedDate: nil,
                bills: [],
                income: [],
                paidEarlyBills: [],
                appliedReserveTransfers: [],
                balanceIsConfirmed: true
            )
        ]
    )

    static var newUserBlank: FloatBudget {
        FloatBudget(
            version: 1,
            activeAccountId: "personal",
            accounts: [
                FloatAccount(
                    id: "personal",
                    name: "Personal",
                    color: "EEE9E7",
                    currentBalance: 0,
                    reserveBalance: 0,
                    reserveGoal: 0,
                    lastConfirmedDate: Date.todayString,
                    bills: [],
                    income: [],
                    paidEarlyBills: [],
                    appliedReserveTransfers: [],
                    balanceIsConfirmed: false
                )
            ]
        )
    }
}
