import Foundation

enum DemoBudget {
    static func make(today: Date = Date()) -> FloatBudget {
        let calendar = Calendar(identifier: .gregorian)

        func day(_ offset: Int) -> String {
            calendar.date(byAdding: .day, value: offset, to: today)?.ymdString ?? today.ymdString
        }

        return FloatBudget(
            version: 1,
            activeAccountId: "personal",
            accounts: [
                FloatAccount(
                    id: "personal",
                    name: "Personal",
                    color: "EEE9E7",
                    currentBalance: 312.54,
                    reserveBalance: 3675,
                    reserveGoal: 8000,
                    lastConfirmedDate: day(-16),
                    bills: [
                        BudgetBill(id: "bill-demo-credit-1", name: "Credit Card 1", amount: 372, startDate: day(-18), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-car", name: "Car Note", amount: 617, startDate: day(-5), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-credit-2", name: "Credit Card 2", amount: 315, startDate: day(-4), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-dental", name: "Dental Installment", amount: 125, startDate: day(-8), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-transfer-joint", name: "Transfer to Joint", amount: 750, startDate: day(-22), frequency: .biweekly, active: true, linkedTransferId: "transfer-demo-joint"),
                        BudgetBill(id: "bill-demo-transfer-reserve", name: "Transfer to Reserve", amount: 500, startDate: day(-21), frequency: .biweekly, active: true)
                    ],
                    income: [
                        BudgetIncome(id: "income-demo-paycheck", label: "Paycheck", amount: 2000, startDate: day(-22), frequency: .biweekly, active: true)
                    ],
                    paidEarlyBills: [],
                    appliedReserveTransfers: [],
                    balanceIsConfirmed: true
                ),
                FloatAccount(
                    id: "joint",
                    name: "Joint",
                    color: "E9ECEF",
                    currentBalance: 1275.48,
                    reserveBalance: 1500,
                    reserveGoal: 6500,
                    lastConfirmedDate: day(-16),
                    bills: [
                        BudgetBill(id: "bill-demo-joint-card-1", name: "Joint Credit Card 1", amount: 570, startDate: day(2), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-rent", name: "Rent", amount: 1600, startDate: day(-3), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-electricity", name: "Electricity", amount: 125, startDate: day(-8), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-gas", name: "Gas", amount: 67, startDate: day(2), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-internet", name: "Internet", amount: 80, startDate: day(-13), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-joint-reserve", name: "Transfer to Reserve", amount: 500, startDate: day(-13), frequency: .biweekly, active: true),
                        BudgetBill(id: "bill-demo-joint-card-2", name: "Joint Credit Card 2", amount: 700, startDate: day(0), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-joint-card-3", name: "Joint Credit Card 3", amount: 230, startDate: day(5), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-pet", name: "Pet Insurance", amount: 50, startDate: day(-6), frequency: .monthly, active: true),
                        BudgetBill(id: "bill-demo-car-insurance", name: "Car Insurance", amount: 235, startDate: day(-3), frequency: .monthly, active: true)
                    ],
                    income: [
                        BudgetIncome(id: "income-demo-transfer-personal", label: "Transfer from Personal", amount: 750, startDate: day(-22), frequency: .biweekly, active: true, linkedTransferId: "transfer-demo-joint"),
                        BudgetIncome(id: "income-demo-spouse", label: "Spouse Contribution", amount: 750, startDate: day(-15), frequency: .biweekly, active: true)
                    ],
                    paidEarlyBills: [],
                    appliedReserveTransfers: [],
                    balanceIsConfirmed: true
                )
            ]
        )
    }
}
