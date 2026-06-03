import Foundation

struct DebtPayoffItem: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var startingBalance: Double
    var currentPrincipal: Double
    var accruedInterest: Double
    var balanceDate: String
    var interestRateAPR: Double
    var minimumPayment: Double
    var plannedMonthlyPayment: Double
    var nextPaymentDate: String

    var estimatedCurrentBalance: Double {
        currentPrincipal + accruedInterest
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case currentBalance
        case startingBalance
        case currentPrincipal
        case accruedInterest
        case balanceDate
        case interestRateAPR
        case minimumPayment
        case plannedMonthlyPayment
        case nextPaymentDate
    }

    init(
        id: String,
        name: String,
        startingBalance: Double,
        currentPrincipal: Double,
        accruedInterest: Double,
        balanceDate: String,
        interestRateAPR: Double,
        minimumPayment: Double,
        plannedMonthlyPayment: Double,
        nextPaymentDate: String
    ) {
        self.id = id
        self.name = name
        self.startingBalance = startingBalance
        self.currentPrincipal = currentPrincipal
        self.accruedInterest = accruedInterest
        self.balanceDate = balanceDate
        self.interestRateAPR = interestRateAPR
        self.minimumPayment = minimumPayment
        self.plannedMonthlyPayment = plannedMonthlyPayment
        self.nextPaymentDate = nextPaymentDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let oldCurrentBalance = try container.decodeIfPresent(Double.self, forKey: .currentBalance) ?? 0

        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startingBalance = try container.decodeIfPresent(Double.self, forKey: .startingBalance) ?? oldCurrentBalance
        currentPrincipal = try container.decodeIfPresent(Double.self, forKey: .currentPrincipal) ?? oldCurrentBalance
        accruedInterest = try container.decodeIfPresent(Double.self, forKey: .accruedInterest) ?? 0
        balanceDate = try container.decodeIfPresent(String.self, forKey: .balanceDate) ?? Date.todayString
        interestRateAPR = try container.decode(Double.self, forKey: .interestRateAPR)
        minimumPayment = try container.decode(Double.self, forKey: .minimumPayment)
        plannedMonthlyPayment = try container.decode(Double.self, forKey: .plannedMonthlyPayment)
        nextPaymentDate = try container.decode(String.self, forKey: .nextPaymentDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startingBalance, forKey: .startingBalance)
        try container.encode(currentPrincipal, forKey: .currentPrincipal)
        try container.encode(accruedInterest, forKey: .accruedInterest)
        try container.encode(balanceDate, forKey: .balanceDate)
        try container.encode(interestRateAPR, forKey: .interestRateAPR)
        try container.encode(minimumPayment, forKey: .minimumPayment)
        try container.encode(plannedMonthlyPayment, forKey: .plannedMonthlyPayment)
        try container.encode(nextPaymentDate, forKey: .nextPaymentDate)
    }
}

struct DebtPayoffSummary {
    var totalDebt: Double
    var monthlyPayments: Double
    var estimatedDebtFreeDate: String?
    var canEstimate: Bool
}

enum DebtPayoffMath {
    static let monthCap = 600

    static func summary(for debts: [DebtPayoffItem]) -> DebtPayoffSummary {
        let totalDebt = debts.reduce(0) { $0 + max(0, $1.estimatedCurrentBalance) }
        let monthlyPayments = debts.reduce(0) { $0 + max(0, $1.plannedMonthlyPayment) }
        guard !debts.isEmpty else {
            return DebtPayoffSummary(totalDebt: 0, monthlyPayments: 0, estimatedDebtFreeDate: nil, canEstimate: true)
        }

        let payoffMonths = debts.map(monthsToPayoff)
        guard payoffMonths.allSatisfy({ $0 != nil }),
              let longest = payoffMonths.compactMap({ $0 }).max(),
              longest <= monthCap else {
            return DebtPayoffSummary(totalDebt: totalDebt, monthlyPayments: monthlyPayments, estimatedDebtFreeDate: nil, canEstimate: false)
        }

        let startDate = debts
            .compactMap { Date.yyyyMMdd.date(from: $0.nextPaymentDate) }
            .min() ?? Date()
        let estimatedDate = Calendar.current.date(byAdding: .month, value: longest, to: startDate) ?? startDate

        return DebtPayoffSummary(
            totalDebt: totalDebt,
            monthlyPayments: monthlyPayments,
            estimatedDebtFreeDate: estimatedDate.ymdString,
            canEstimate: true
        )
    }

    static func monthsToPayoff(_ debt: DebtPayoffItem) -> Int? {
        var balance = debt.estimatedCurrentBalance
        guard balance > 0 else { return 0 }

        let payment = debt.plannedMonthlyPayment
        let monthlyRate = max(0, debt.interestRateAPR) / 100 / 12
        guard payment > balance * monthlyRate else { return nil }

        for month in 1...monthCap {
            balance += balance * monthlyRate
            balance -= payment
            if balance <= 0 {
                return month
            }
        }

        return nil
    }
}
