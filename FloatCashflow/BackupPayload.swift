import Foundation

struct FloatBackupPayload: Codable {
    var version = 1
    var budget: FloatBudget

    enum CodingKeys: String, CodingKey {
        case version
        case budget
        case debts
        case debtPayoff
        case debtPayoffData
        case debtPayoffItems
        case debtPayoffLedger
    }

    init(budget: FloatBudget) {
        self.budget = budget
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        budget = try container.decode(FloatBudget.self, forKey: .budget)

        var legacyDebts = [DebtOverviewItem]()
        legacyDebts += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoffItems)) ?? []
        legacyDebts += (try? container.decode([DebtOverviewItem].self, forKey: .debts)) ?? []
        legacyDebts += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoff)) ?? []
        legacyDebts += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoffLedger)) ?? []
        legacyDebts += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoffData)) ?? []
        legacyDebts += (try? container.decode(LegacyDebtPayoffData.self, forKey: .debtPayoff))?.items ?? []
        legacyDebts += (try? container.decode(LegacyDebtPayoffData.self, forKey: .debtPayoffData))?.items ?? []
        legacyDebts += (try? container.decode(LegacyDebtPayoffData.self, forKey: .debtPayoffLedger))?.items ?? []

        if !legacyDebts.isEmpty {
            budget.migrateLegacyDebtsToOutItems(legacyDebts)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(budget, forKey: .budget)
    }
}

private struct LegacyDebtPayoffData: Decodable {
    var items: [DebtOverviewItem]

    enum CodingKeys: String, CodingKey {
        case items
        case debts
        case debtPayoff
        case debtPayoffItems
        case debtPayoffLedger
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = []
        items += (try? container.decode([DebtOverviewItem].self, forKey: .items)) ?? []
        items += (try? container.decode([DebtOverviewItem].self, forKey: .debts)) ?? []
        items += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoff)) ?? []
        items += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoffItems)) ?? []
        items += (try? container.decode([DebtOverviewItem].self, forKey: .debtPayoffLedger)) ?? []
    }
}

private extension FloatBudget {
    mutating func migrateLegacyDebtsToOutItems(_ debts: [DebtOverviewItem]) {
        guard let accountIndex = accounts.firstIndex(where: { $0.id == activeAccountId }) ?? accounts.indices.first else {
            return
        }

        var existingDebtNames = Set(
            accounts[accountIndex].bills.compactMap { bill in
                bill.debtDetails == nil ? nil : bill.name.normalizedLegacyDebtName
            }
        )

        for debt in debts {
            let normalizedName = debt.name.normalizedLegacyDebtName
            guard !normalizedName.isEmpty, !existingDebtNames.contains(normalizedName) else {
                continue
            }

            accounts[accountIndex].bills.append(
                BudgetBill(
                    id: uniqueLegacyDebtBillId(for: debt, in: accounts[accountIndex]),
                    name: debt.name,
                    amount: debt.plannedMonthlyPayment,
                    startDate: debt.nextPaymentDate,
                    frequency: .monthly,
                    active: true,
                    debtDetails: BudgetDebtDetails(
                        startingBalance: debt.startingBalance,
                        currentPrincipal: debt.currentPrincipal,
                        accruedInterest: debt.accruedInterest,
                        balanceDate: debt.balanceDate,
                        interestRateAPR: debt.interestRateAPR,
                        minimumPayment: debt.minimumPayment
                    )
                )
            )
            existingDebtNames.insert(normalizedName)
        }
    }

    func uniqueLegacyDebtBillId(for debt: DebtOverviewItem, in account: FloatAccount) -> String {
        let base = "legacy-debt-\(debt.id.normalizedLegacyDebtName.isEmpty ? debt.name.normalizedLegacyDebtName : debt.id.normalizedLegacyDebtName)"
        var candidate = base.isEmpty ? "legacy-debt" : base
        var suffix = 2
        let existingIds = Set(account.bills.map(\.id))

        while existingIds.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }

        return candidate
    }
}

private extension String {
    var normalizedLegacyDebtName: String {
        lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
