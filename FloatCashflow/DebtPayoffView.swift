import SwiftUI

struct DebtPayoffView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var budgetStore: BudgetStore
    @ObservedObject var store: DebtPayoffStore
    @State private var activeSheet: DebtPayoffSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.floatSubtle, .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        note
                        summaryCard
                        debtList
                        addButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
            }
            .navigationTitle("Debt Payoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.floatText)
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .newDebt:
                    DebtEditor { name, starting, principal, accrued, balanceDate, apr, minimum, planned, paymentDate in
                        store.addDebt(
                            name: name,
                            startingBalance: starting,
                            currentPrincipal: principal,
                            accruedInterest: accrued,
                            balanceDate: balanceDate,
                            interestRateAPR: apr,
                            minimumPayment: minimum,
                            plannedMonthlyPayment: planned,
                            nextPaymentDate: paymentDate
                        )
                    }
                    .presentationDetents([.fraction(0.82), .large])
                    .presentationDragIndicator(.visible)
                case .editDebt(let debt):
                    DebtEditor(debt: debt) { name, starting, principal, accrued, balanceDate, apr, minimum, planned, paymentDate in
                        store.updateDebt(
                            debt,
                            name: name,
                            startingBalance: starting,
                            currentPrincipal: principal,
                            accruedInterest: accrued,
                            balanceDate: balanceDate,
                            interestRateAPR: apr,
                            minimumPayment: minimum,
                            plannedMonthlyPayment: planned,
                            nextPaymentDate: paymentDate
                        )
                    } onDelete: {
                        store.deleteDebt(debt)
                    }
                    .presentationDetents([.fraction(0.86), .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onAppear {
                store.syncFromBudget(budgetStore.budget)
            }
        }
    }

    private var note: some View {
        Text("Changes in Plan will sync here for payoff planning. Changes made inside this tool stay planning-only and will not change Plan or your cash-flow timeline.")
            .font(.system(size: 12))
            .foregroundStyle(Color.floatTextFaint)
            .lineSpacing(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryCard: some View {
        let summary = store.summary

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                summaryMetric("Total Debt", money(summary.totalDebt), color: .floatText)
                Spacer()
                summaryMetric("Monthly Payments", money(summary.monthlyPayments), color: .floatTextMid)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Estimated Debt-Free Date")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.floatTextFaint)
                Text(summaryDateText(summary))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(summary.canEstimate ? Color.floatAccent : Color.floatWarning)
            }
        }
        .padding(14)
        .background(.white.opacity(0.62))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var debtList: some View {
        VStack(spacing: 0) {
            if store.ledger.debts.isEmpty {
                Text("No debts added yet.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.floatTextFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 14)
            } else {
                ForEach(store.ledger.debts) { debt in
                    Button {
                        activeSheet = .editDebt(debt)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(debt.name)
                                .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.floatText)
                                    .lineLimit(1)
                                Text("APR \(debt.interestRateAPR.formatted(.number.precision(.fractionLength(0...3))))% · next \(labelDate(debt.nextPaymentDate))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.floatTextFaint)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(money(debt.estimatedCurrentBalance))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.floatText)
                                Text("\(money(debt.plannedMonthlyPayment))/mo")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.floatTextSubtle)
                            }
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.floatDivider)
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            activeSheet = .newDebt
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("Add Debt")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color.floatText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(.white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.07), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func summaryMetric(_ label: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func summaryDateText(_ summary: DebtPayoffSummary) -> String {
        if !summary.canEstimate {
            return "Not enough to estimate payoff."
        }

        guard let date = summary.estimatedDebtFreeDate else {
            return "-"
        }

        return labelDate(date)
    }
}

private enum DebtPayoffSheet: Identifiable {
    case newDebt
    case editDebt(DebtPayoffItem)

    var id: String {
        switch self {
        case .newDebt:
            return "new-debt"
        case .editDebt(let debt):
            return "edit-\(debt.id)"
        }
    }
}

private struct DebtEditor: View {
    @Environment(\.dismiss) private var dismiss

    var debt: DebtPayoffItem?
    var onSave: (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var startingBalance: String
    @State private var currentPrincipal: String
    @State private var accruedInterest: String
    @State private var balanceDate: Date
    @State private var apr: String
    @State private var minimumPayment: String
    @State private var plannedPayment: String
    @State private var nextPaymentDate: Date
    @State private var showDeleteAlert = false
    @State private var showIncompleteSnapshotAlert = false
    @State private var showLargeBalanceAlert = false

    init(
        debt: DebtPayoffItem? = nil,
        onSave: @escaping (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.debt = debt
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: debt?.name ?? "")
        _startingBalance = State(initialValue: debt.map { String($0.startingBalance) } ?? "")
        _currentPrincipal = State(initialValue: debt.map { String($0.currentPrincipal) } ?? "")
        _accruedInterest = State(initialValue: debt.map { String($0.accruedInterest) } ?? "")
        _balanceDate = State(initialValue: debt.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) } ?? Date())
        _apr = State(initialValue: debt.map { String($0.interestRateAPR) } ?? "")
        _minimumPayment = State(initialValue: debt.map { String($0.minimumPayment) } ?? "")
        _plannedPayment = State(initialValue: debt.map { String($0.plannedMonthlyPayment) } ?? "")
        _nextPaymentDate = State(initialValue: debt.flatMap { Date.yyyyMMdd.date(from: $0.nextPaymentDate) } ?? Date())
    }

    var body: some View {
        EditorShell(accountColor: "F5F5F5", title: debt == nil ? "New Debt" : "Edit Debt") {
            debtLabeled("Name") {
                FloatTextField(placeholder: "Student Loan", text: $name)
            }
            debtLabeled("Starting Balance") {
                FloatTextField(placeholder: "93462.17", text: $startingBalance, keyboard: .decimalPad)
            }
            debtLabeled("Payment Date") {
                debtDatePicker(date: $nextPaymentDate)
            }
            debtLabeled("Interest rate APR") {
                FloatTextField(placeholder: "4.485", text: $apr, keyboard: .decimalPad)
            }
            debtLabeled("Minimum payment") {
                FloatTextField(placeholder: "0.00", text: $minimumPayment, keyboard: .decimalPad)
            }
            debtLabeled("Current Principal") {
                FloatTextField(placeholder: "70803.93", text: $currentPrincipal, keyboard: .decimalPad)
            }
            debtLabeled("Accrued Interest") {
                FloatTextField(placeholder: "243.60", text: $accruedInterest, keyboard: .decimalPad)
            }
            debtLabeled("Balance Date") {
                debtDatePicker(date: $balanceDate)
            }
            debtLabeled("Monthly Payment") {
                FloatTextField(placeholder: "0.00", text: $plannedPayment, keyboard: .decimalPad)
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        cancel()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    attemptSave()
                }
            }
        }
        .interactiveDismissDisabled(snapshotHasChanges)
        .alert("Delete \(debt?.name ?? "Debt")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
        .alert("Update Balance Snapshot", isPresented: $showIncompleteSnapshotAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Current Principal, Accrued Interest, and Balance Date need to be updated together.")
        }
        .alert("Balance Looks Far Off", isPresented: $showLargeBalanceAlert) {
            Button("Review", role: .cancel) {}
            Button("Save Anyway") {
                saveAndDismiss()
            }
        } message: {
            Text("The new principal plus accrued interest is far from the previous balance snapshot.")
        }
    }

    private func debtLabeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.floatTextFaint)
            content()
        }
    }

    private var snapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.issue(
            originalPrincipal: debt?.currentPrincipal,
            originalAccruedInterest: debt?.accruedInterest,
            originalBalanceDate: debt.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            originalAPR: debt?.interestRateAPR,
            originalMonthlyPayment: debt?.plannedMonthlyPayment,
            originalPaymentDate: debt.flatMap { Date.yyyyMMdd.date(from: $0.nextPaymentDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var incompleteSnapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.incompleteSnapshotIssue(
            originalPrincipal: debt?.currentPrincipal,
            originalAccruedInterest: debt?.accruedInterest,
            originalBalanceDate: debt.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var snapshotHasChanges: Bool {
        guard let debt,
              let originalDate = Date.yyyyMMdd.date(from: debt.balanceDate) else {
            return false
        }

        let principal = Double(currentPrincipal) ?? debt.currentPrincipal
        let interest = Double(accruedInterest) ?? debt.accruedInterest
        return abs(principal - debt.currentPrincipal) >= 0.005 ||
            abs(interest - debt.accruedInterest) >= 0.005 ||
            balanceDate.ymdString != originalDate.ymdString
    }

    private func attemptSave() {
        switch snapshotIssue {
        case .incompleteSnapshot:
            showIncompleteSnapshotAlert = true
        case .largeBalanceChange:
            showLargeBalanceAlert = true
        case nil:
            saveAndDismiss()
        }
    }

    private func cancel() {
        attemptExit()
    }

    private func attemptExit() {
        switch snapshotIssue {
        case .incompleteSnapshot:
            showIncompleteSnapshotAlert = true
        case .largeBalanceChange:
            showLargeBalanceAlert = true
        case nil:
            dismiss()
        }
    }

    private func saveAndDismiss() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        onSave(
            trimmedName,
            Double(startingBalance) ?? debt?.startingBalance ?? 0,
            Double(currentPrincipal) ?? debt?.currentPrincipal ?? 0,
            Double(accruedInterest) ?? debt?.accruedInterest ?? 0,
            balanceDate,
            Double(apr) ?? debt?.interestRateAPR ?? 0,
            Double(minimumPayment) ?? debt?.minimumPayment ?? 0,
            Double(plannedPayment) ?? debt?.plannedMonthlyPayment ?? 0,
            nextPaymentDate
        )
        dismiss()
    }

    private func debtDatePicker(date: Binding<Date>) -> some View {
        DatePicker("", selection: date, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(.system(size: 14))
            .tint(Color.floatText)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.floatBorder, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
