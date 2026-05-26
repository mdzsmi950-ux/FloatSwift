import Foundation

enum DebtSnapshotIssue {
    case incompleteSnapshot
    case largeBalanceChange
}

enum DebtSnapshotValidation {
    static func incompleteSnapshotIssue(
        originalPrincipal: Double?,
        originalAccruedInterest: Double?,
        originalBalanceDate: Date?,
        currentPrincipalText: String,
        accruedInterestText: String,
        balanceDate: Date
    ) -> DebtSnapshotIssue? {
        guard let originalPrincipal,
              let originalAccruedInterest,
              let originalBalanceDate else {
            return nil
        }

        let currentPrincipal = Double(currentPrincipalText) ?? originalPrincipal
        let accruedInterest = Double(accruedInterestText) ?? originalAccruedInterest
        let principalChanged = !amountsMatch(currentPrincipal, originalPrincipal)
        let interestChanged = !amountsMatch(accruedInterest, originalAccruedInterest)
        let dateChanged = balanceDate.ymdString != originalBalanceDate.ymdString
        let changeCount = [principalChanged, interestChanged, dateChanged].filter { $0 }.count

        return (1...2).contains(changeCount) ? .incompleteSnapshot : nil
    }

    static func issue(
        originalPrincipal: Double?,
        originalAccruedInterest: Double?,
        originalBalanceDate: Date?,
        originalAPR: Double?,
        originalMonthlyPayment: Double?,
        originalPaymentDate: Date?,
        currentPrincipalText: String,
        accruedInterestText: String,
        balanceDate: Date
    ) -> DebtSnapshotIssue? {
        guard let originalPrincipal,
              let originalAccruedInterest,
              let originalBalanceDate,
              let originalAPR,
              let originalMonthlyPayment,
              let originalPaymentDate else {
            return nil
        }

        if incompleteSnapshotIssue(
            originalPrincipal: originalPrincipal,
            originalAccruedInterest: originalAccruedInterest,
            originalBalanceDate: originalBalanceDate,
            currentPrincipalText: currentPrincipalText,
            accruedInterestText: accruedInterestText,
            balanceDate: balanceDate
        ) == .incompleteSnapshot {
            return .incompleteSnapshot
        }

        let currentPrincipal = Double(currentPrincipalText) ?? originalPrincipal
        let accruedInterest = Double(accruedInterestText) ?? originalAccruedInterest
        let principalChanged = !amountsMatch(currentPrincipal, originalPrincipal)
        let interestChanged = !amountsMatch(accruedInterest, originalAccruedInterest)
        let dateChanged = balanceDate.ymdString != originalBalanceDate.ymdString

        if principalChanged, interestChanged, dateChanged {
            let expected = projectedSnapshot(
                principal: originalPrincipal,
                accruedInterest: originalAccruedInterest,
                balanceDate: originalBalanceDate,
                apr: originalAPR,
                monthlyPayment: originalMonthlyPayment,
                paymentDate: originalPaymentDate,
                targetDate: balanceDate
            )
            let principalThreshold = max(100, max(originalMonthlyPayment, 1) * 0.35)
            let interestThreshold = max(50, max(expected.accruedInterest, 1) * 0.35)

            if abs(currentPrincipal - expected.principal) > principalThreshold ||
                abs(accruedInterest - expected.accruedInterest) > interestThreshold {
                return .largeBalanceChange
            }
        }

        return nil
    }

    private static func amountsMatch(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.005
    }

    private static func projectedSnapshot(
        principal: Double,
        accruedInterest: Double,
        balanceDate: Date,
        apr: Double,
        monthlyPayment: Double,
        paymentDate: Date,
        targetDate: Date
    ) -> (principal: Double, accruedInterest: Double) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: balanceDate)
        let end = calendar.startOfDay(for: targetDate)
        guard end > start else {
            return (principal, accruedInterest)
        }

        let dailyRate = max(0, apr) / 100 / 365
        var projectedPrincipal = max(0, principal)
        var projectedInterest = max(0, accruedInterest)
        var day = start

        while day < end {
            if isPaymentDate(day, scheduledFrom: paymentDate), monthlyPayment > 0 {
                var remainingPayment = monthlyPayment
                let interestPayment = min(projectedInterest, remainingPayment)
                projectedInterest -= interestPayment
                remainingPayment -= interestPayment
                projectedPrincipal = max(0, projectedPrincipal - remainingPayment)
            }

            projectedInterest += projectedPrincipal * dailyRate
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return (projectedPrincipal, projectedInterest)
    }

    private static func isPaymentDate(_ date: Date, scheduledFrom paymentDate: Date) -> Bool {
        let calendar = Calendar.current
        let scheduledStart = calendar.startOfDay(for: paymentDate)
        guard date >= scheduledStart else { return false }

        let components = calendar.dateComponents([.day], from: scheduledStart)
        guard let scheduledDay = components.day else { return false }
        let currentDay = calendar.component(.day, from: date)

        if currentDay == scheduledDay {
            return true
        }

        guard let range = calendar.range(of: .day, in: .month, for: date),
              scheduledDay > range.upperBound - 1 else {
            return false
        }

        return currentDay == range.upperBound - 1
    }
}
