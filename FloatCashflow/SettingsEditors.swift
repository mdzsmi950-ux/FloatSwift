import SwiftUI

struct BillEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var bill: BudgetBill?
    var onSave: (String, Double, Date, Frequency) -> Void
    var onDelete: (() -> Void)?
    var onPaidEarly: (() -> Void)?

    @State private var name: String
    @State private var amount: String
    @State private var date: Date
    @State private var dateWasChosen: Bool
    @State private var saveAttempted = false
    @State private var validationError: String?
    @State private var frequency: Frequency
    @State private var showDeleteAlert = false

    init(
        accountColor: String,
        bill: BudgetBill? = nil,
        onSave: @escaping (String, Double, Date, Frequency) -> Void,
        onDelete: (() -> Void)? = nil,
        onPaidEarly: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete
        self.onPaidEarly = onPaidEarly
        _name = State(initialValue: bill?.name ?? "")
        _amount = State(initialValue: bill.map { String($0.amount) } ?? "")
        _date = State(initialValue: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
        _dateWasChosen = State(initialValue: bill != nil)
        _frequency = State(initialValue: bill?.frequency ?? .monthly)
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: bill == nil ? "New Bill" : "Edit Bill") {
            labeled("Bill name") {
                FloatTextField(placeholder: "", text: $name)
            }
            labeled("Amount") {
                FloatTextField(placeholder: "", text: $amount, keyboard: .decimalPad)
            }
            labeled("Frequency") {
                FrequencyPicker(frequency: $frequency)
            }
            labeled("Date") {
                SheetDatePicker(
                    date: $date,
                    wasChosen: $dateWasChosen,
                    showMissingState: saveAttempted && !dateWasChosen
                )
            }

            if let onPaidEarly {
                SheetActionButton(title: "Paid Early", fill: .secondary) {
                    onPaidEarly()
                    dismiss()
                }
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    saveAttempted = true
                    let nextName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !nextName.isEmpty else {
                        validationError = "Enter a bill name."
                        return
                    }
                    guard let parsedAmount = parseAmount(amount) else {
                        validationError = "Enter a valid bill amount."
                        return
                    }
                    guard dateWasChosen else {
                        validationError = "Choose a bill date."
                        return
                    }
                    validationError = nil
                    onSave(nextName, parsedAmount, date, frequency)
                    dismiss()
                }
            }
            settingsFieldError(validationError)
        }
        .alert("Delete \(bill?.name ?? "Bill")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}

struct IncomeEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var income: BudgetIncome?
    var onSave: (String, Double, Date, Frequency) -> Void
    var onDelete: (() -> Void)?

    @State private var label: String
    @State private var amount: String
    @State private var date: Date
    @State private var dateWasChosen: Bool
    @State private var saveAttempted = false
    @State private var validationError: String?
    @State private var frequency: Frequency
    @State private var showDeleteAlert = false

    init(
        accountColor: String,
        income: BudgetIncome? = nil,
        onSave: @escaping (String, Double, Date, Frequency) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.income = income
        self.onSave = onSave
        self.onDelete = onDelete
        _label = State(initialValue: income?.label ?? "Paycheck")
        _amount = State(initialValue: income.map { String($0.amount) } ?? "")
        _date = State(initialValue: income.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
        _dateWasChosen = State(initialValue: income != nil)
        _frequency = State(initialValue: income?.frequency ?? .biweekly)
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: income == nil ? "New Income" : "Edit Income") {
            labeled("Name") {
                FloatTextField(placeholder: "Paycheck", text: $label)
            }
            labeled("Amount") {
                FloatTextField(placeholder: "", text: $amount, keyboard: .decimalPad)
            }
            labeled("Frequency") {
                FrequencyPicker(frequency: $frequency)
            }
            labeled("Date") {
                SheetDatePicker(
                    date: $date,
                    wasChosen: $dateWasChosen,
                    showMissingState: saveAttempted && !dateWasChosen
                )
            }

            HStack(spacing: 10) {
                if onDelete != nil {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Confirm", fill: .primary) {
                    saveAttempted = true
                    let nextLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !nextLabel.isEmpty else {
                        validationError = "Enter an income name."
                        return
                    }
                    guard let parsedAmount = parseAmount(amount) else {
                        validationError = "Enter a valid income amount."
                        return
                    }
                    guard dateWasChosen else {
                        validationError = "Choose an income date."
                        return
                    }
                    validationError = nil
                    onSave(nextLabel, parsedAmount, date, frequency)
                    dismiss()
                }
            }
            settingsFieldError(validationError)
        }
        .alert("Delete \(income?.label ?? "Income")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}

struct DebtBillEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var bill: BudgetBill?
    var onSave: (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var startingBalance: String
    @State private var currentPrincipal: String
    @State private var accruedInterest: String
    @State private var balanceDate: Date
    @State private var apr: String
    @State private var minimumPayment: String
    @State private var monthlyPayment: String
    @State private var paymentDate: Date
    @State private var validationError: String?
    @State private var showDeleteAlert = false
    @State private var showIncompleteSnapshotAlert = false
    @State private var showLargeBalanceAlert = false

    init(
        accountColor: String,
        bill: BudgetBill? = nil,
        onSave: @escaping (String, Double, Double, Double, Date, Double, Double, Double, Date) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete

        let details = bill?.debtDetails
        _name = State(initialValue: bill?.name ?? "")
        _startingBalance = State(initialValue: details.map { String($0.startingBalance) } ?? "")
        _currentPrincipal = State(initialValue: details.map { String($0.currentPrincipal) } ?? "")
        _accruedInterest = State(initialValue: details.map { String($0.accruedInterest) } ?? "")
        _balanceDate = State(initialValue: details.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) } ?? Date())
        _apr = State(initialValue: details.map { String($0.interestRateAPR) } ?? "")
        _minimumPayment = State(initialValue: details.map { String($0.minimumPayment) } ?? "")
        _monthlyPayment = State(initialValue: bill.map { String($0.amount) } ?? "")
        _paymentDate = State(initialValue: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: bill == nil ? "New Debt" : "Debt Details") {
            payoffSummary

            labeled("Debt Name") {
                FloatTextField(placeholder: "Student Loan", text: $name)
            }
            labeled("Starting Balance") {
                FloatTextField(placeholder: "93462.17", text: $startingBalance, keyboard: .decimalPad)
            }
            labeled("Payment Date") {
                editorDatePicker(date: $paymentDate)
            }
            labeled("Interest Rate") {
                FloatTextField(placeholder: "4.485", text: $apr, keyboard: .decimalPad)
            }
            labeled("Minimum Payment") {
                FloatTextField(placeholder: "0.00", text: $minimumPayment, keyboard: .decimalPad)
            }
            labeled("Current Principal") {
                FloatTextField(placeholder: "70803.93", text: $currentPrincipal, keyboard: .decimalPad)
            }
            labeled("Accrued Interest") {
                FloatTextField(placeholder: "243.60", text: $accruedInterest, keyboard: .decimalPad)
            }
            labeled("Balance Date") {
                editorDatePicker(date: $balanceDate)
            }
            labeled("Monthly Payment") {
                FloatTextField(placeholder: "0.00", text: $monthlyPayment, keyboard: .decimalPad)
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
            settingsFieldError(validationError)
        }
        .interactiveDismissDisabled(snapshotHasChanges)
        .alert("Delete \(bill?.name ?? "Debt")?", isPresented: $showDeleteAlert) {
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

    private var payoffSummary: some View {
        let balance = (Double(currentPrincipal) ?? bill?.debtDetails?.currentPrincipal ?? 0) +
            (Double(accruedInterest) ?? bill?.debtDetails?.accruedInterest ?? 0)
        let payment = Double(monthlyPayment) ?? bill?.amount ?? 0
        let rate = Double(apr) ?? bill?.debtDetails?.interestRateAPR ?? 0
        let months = estimatedMonths(balance: balance, payment: payment, apr: rate)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.floatTextFaint)
                .tracking(0.8)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                detailMetric("Current Debt", money(balance))
                Spacer()
                detailMetric("Payoff", payoffText(months))
            }
        }
        .padding(12)
        .background(.white.opacity(0.52))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.black.opacity(0.06), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detailMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.floatTextFaint)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.floatText)
        }
    }

    private func payoffText(_ months: Int?) -> String {
        guard let months else { return "Not enough" }
        if months == 0 { return "Paid off" }
        let date = Calendar.current.date(byAdding: .month, value: months, to: paymentDate) ?? paymentDate
        return labelDate(date.ymdString)
    }

    private func estimatedMonths(balance: Double, payment: Double, apr: Double) -> Int? {
        var balance = balance
        guard balance > 0 else { return 0 }
        let monthlyRate = max(0, apr) / 100 / 12
        guard payment > balance * monthlyRate else { return nil }

        for month in 1...600 {
            balance += balance * monthlyRate
            balance -= payment
            if balance <= 0 {
                return month
            }
        }

        return nil
    }

    private var snapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.issue(
            originalPrincipal: bill?.debtDetails?.currentPrincipal,
            originalAccruedInterest: bill?.debtDetails?.accruedInterest,
            originalBalanceDate: bill?.debtDetails.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            originalAPR: bill?.debtDetails?.interestRateAPR,
            originalMonthlyPayment: bill?.amount,
            originalPaymentDate: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var incompleteSnapshotIssue: DebtSnapshotIssue? {
        DebtSnapshotValidation.incompleteSnapshotIssue(
            originalPrincipal: bill?.debtDetails?.currentPrincipal,
            originalAccruedInterest: bill?.debtDetails?.accruedInterest,
            originalBalanceDate: bill?.debtDetails.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) },
            currentPrincipalText: currentPrincipal,
            accruedInterestText: accruedInterest,
            balanceDate: balanceDate
        )
    }

    private var snapshotHasChanges: Bool {
        guard let details = bill?.debtDetails,
              let originalDate = Date.yyyyMMdd.date(from: details.balanceDate) else {
            return false
        }

        let principal = Double(currentPrincipal) ?? details.currentPrincipal
        let interest = Double(accruedInterest) ?? details.accruedInterest
        return abs(principal - details.currentPrincipal) >= 0.005 ||
            abs(interest - details.accruedInterest) >= 0.005 ||
            balanceDate.ymdString != originalDate.ymdString
    }

    private func attemptSave() {
        if let debtValidationError {
            validationError = debtValidationError
            return
        }
        validationError = nil

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
        guard debtValidationError == nil,
              let starting = parseAmount(startingBalance),
              let principal = parseAmount(currentPrincipal),
              let interest = parseAmount(accruedInterest),
              let rate = parseAmount(apr),
              let minimum = parseAmount(minimumPayment),
              let monthly = parseAmount(monthlyPayment) else {
            validationError = debtValidationError ?? "Enter valid debt details."
            return
        }
        onSave(
            trimmedName,
            starting,
            principal,
            interest,
            balanceDate,
            rate,
            minimum,
            monthly,
            paymentDate
        )
        dismiss()
    }

    private var debtValidationError: String? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Enter a debt name."
        }
        guard parseAmount(startingBalance) != nil else { return "Enter a valid starting balance." }
        guard parseAmount(currentPrincipal) != nil else { return "Enter a valid current principal." }
        guard parseAmount(accruedInterest) != nil else { return "Enter valid accrued interest." }
        guard parseAmount(apr) != nil else { return "Enter a valid interest rate." }
        guard parseAmount(minimumPayment) != nil else { return "Enter a valid minimum payment." }
        guard parseAmount(monthlyPayment) != nil else { return "Enter a valid monthly payment." }
        return nil
    }

    private func editorDatePicker(date: Binding<Date>) -> some View {
        DatePicker("", selection: date, displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(.system(size: 14))
            .tint(Color.floatText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
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

struct AccountEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var account: FloatAccount?
    var canDelete: Bool
    var isShownInWidget: Bool
    var currentWidgetAccountName: String?
    var onSave: (String) -> Void
    var onWidgetVisibilityChange: ((Bool) -> Void)?
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var showInWidget: Bool
    @State private var ownsWidgetSelection: Bool
    @State private var replacementAccountName: String?
    @State private var validationError: String?
    @State private var showDeleteAlert = false
    @State private var showReplaceWidgetAlert = false

    init(
        accountColor: String,
        account: FloatAccount? = nil,
        canDelete: Bool = false,
        isShownInWidget: Bool = false,
        currentWidgetAccountName: String? = nil,
        onSave: @escaping (String) -> Void,
        onWidgetVisibilityChange: ((Bool) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.account = account
        self.canDelete = canDelete
        self.isShownInWidget = isShownInWidget
        self.currentWidgetAccountName = currentWidgetAccountName
        self.onSave = onSave
        self.onWidgetVisibilityChange = onWidgetVisibilityChange
        self.onDelete = onDelete
        _name = State(initialValue: account?.name ?? "")
        _showInWidget = State(initialValue: isShownInWidget)
        _ownsWidgetSelection = State(initialValue: isShownInWidget)
        _replacementAccountName = State(initialValue: currentWidgetAccountName)
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: account == nil ? "New Account" : "Edit Account") {
            labeled("Account name") {
                FloatTextField(placeholder: "", text: $name)
            }

            if account != nil {
                labeled("Widget") {
                    Toggle(isOn: widgetToggleBinding) {
                        Text("Show in widget")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.floatText)
                    }
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

            HStack(spacing: 10) {
                if canDelete {
                    SheetActionButton(title: "Delete", fill: .secondary) {
                        showDeleteAlert = true
                    }
                } else {
                    SheetActionButton(title: "Cancel", fill: .secondary) {
                        dismiss()
                    }
                }

                SheetActionButton(title: "Save", fill: .primary) {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else {
                        validationError = "Enter an account name."
                        return
                    }
                    validationError = nil
                    onSave(trimmedName)
                    dismiss()
                }
            }
            settingsFieldError(validationError)
        }
        .alert("Delete \(account?.name ?? "Account")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("All balances and transactions under this account will be lost.")
        }
        .alert("\(replacementAccountName ?? "Another account") is on", isPresented: $showReplaceWidgetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Replace") {
                showInWidget = true
                ownsWidgetSelection = true
                replacementAccountName = nil
                onWidgetVisibilityChange?(true)
            }
        } message: {
            Text("Do you want to replace it?")
        }
    }

    private var widgetToggleBinding: Binding<Bool> {
        Binding {
            showInWidget
        } set: { nextValue in
            guard nextValue else {
                showInWidget = false
                ownsWidgetSelection = false
                onWidgetVisibilityChange?(false)
                return
            }

            if ownsWidgetSelection || replacementAccountName == nil {
                showInWidget = true
                ownsWidgetSelection = true
                onWidgetVisibilityChange?(true)
            } else {
                showInWidget = false
                showReplaceWidgetAlert = true
            }
        }
    }
}

struct EditorShell<Content: View>: View {
    var accountColor: String
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: accountColor).opacity(0.75), Color(hex: accountColor).opacity(0.42), .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.floatText)
                        .padding(.bottom, 10)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.visible)
            .scrollBounceBehavior(.always, axes: .vertical)
        }
    }
}

struct SheetActionButton: View {
    enum Fill {
        case primary
        case secondary
    }

    var title: String
    var fill: Fill
    var action: () -> Void

    var body: some View {
        Button {
            UIApplication.dismissKeyboard()
            action()
        } label: {
            Text(title)
        }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.floatText)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(fill == .primary ? .white.opacity(0.78) : .white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SheetDatePicker: View {
    @Binding var date: Date
    @Binding var wasChosen: Bool
    var showMissingState: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            DatePicker("", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(.system(size: 14))
                .tint(Color.floatText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .opacity(wasChosen ? 1 : 0.02)
                .onChange(of: date) {
                    wasChosen = true
                }
                .simultaneousGesture(TapGesture().onEnded {
                    wasChosen = true
                })

            if !wasChosen {
                Text("Select date")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.floatTextFaint)
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(showMissingState ? Color.floatWarning : Color.floatBorder, lineWidth: showMissingState ? 1 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FrequencyPicker: View {
    @Binding var frequency: Frequency

    var body: some View {
        Picker("Frequency", selection: $frequency) {
            ForEach(Frequency.allCases) { item in
                Text(item.label).tag(item)
            }
        }
        .pickerStyle(.menu)
        .font(.system(size: 14))
        .foregroundStyle(Color.floatText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 40)
        .padding(.horizontal, 12)
        .background(.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.floatBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

@ViewBuilder
private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title)
            .font(.system(size: 12))
            .foregroundStyle(Color.floatText)
        content()
    }
}

@ViewBuilder
func settingsFieldError(_ message: String?) -> some View {
    if let message {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.floatWarning)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
