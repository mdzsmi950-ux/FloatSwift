import SwiftUI

struct BillEditor: View {
    @Environment(\.dismiss) private var dismiss

    var accountColor: String
    var bill: BudgetBill?
    var onSave: (String, Double, Date, Frequency, BudgetDebtDetails?) -> Void
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
    @State private var isDebt: Bool
    @State private var startingBalance: String
    @State private var currentPrincipal: String
    @State private var accruedInterest: String
    @State private var balanceDate: Date
    @State private var apr: String
    @State private var minimumPayment: String

    init(
        accountColor: String,
        bill: BudgetBill? = nil,
        onSave: @escaping (String, Double, Date, Frequency, BudgetDebtDetails?) -> Void,
        onDelete: (() -> Void)? = nil,
        onPaidEarly: (() -> Void)? = nil
    ) {
        self.accountColor = accountColor
        self.bill = bill
        self.onSave = onSave
        self.onDelete = onDelete
        self.onPaidEarly = onPaidEarly
        let details = bill?.debtDetails
        _name = State(initialValue: bill?.name ?? "")
        _amount = State(initialValue: bill.map { String($0.amount) } ?? "")
        _date = State(initialValue: bill.flatMap { Date.yyyyMMdd.date(from: $0.startDate) } ?? Date())
        _dateWasChosen = State(initialValue: bill != nil)
        _frequency = State(initialValue: bill?.frequency ?? .monthly)
        _isDebt = State(initialValue: details != nil)
        _startingBalance = State(initialValue: details.map { String($0.startingBalance) } ?? "")
        _currentPrincipal = State(initialValue: details.map { String($0.currentPrincipal) } ?? "")
        _accruedInterest = State(initialValue: details.map { String($0.accruedInterest) } ?? "")
        _balanceDate = State(initialValue: details.flatMap { Date.yyyyMMdd.date(from: $0.balanceDate) } ?? Date())
        _apr = State(initialValue: details.map { String($0.interestRateAPR) } ?? "")
        _minimumPayment = State(initialValue: details.map { String($0.minimumPayment) } ?? "")
    }

    var body: some View {
        EditorShell(accountColor: accountColor, title: bill == nil ? "New Out" : "Edit Out") {
            labeled("Name") {
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
            labeled("Is this a debt?") {
                Toggle(isOn: $isDebt) {
                    Text(isDebt ? "Debt" : "Normal Out")
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

            if isDebt {
                payoffSummary

                labeled("Starting Balance") {
                    FloatTextField(placeholder: "93462.17", text: $startingBalance, keyboard: .decimalPad)
                }
                labeled("Interest Rate") {
                    FloatTextField(placeholder: "4.485", text: $apr, keyboard: .decimalPad)
                }
                labeled("Required Minimum") {
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
                        validationError = "Enter an Out name."
                        return
                    }
                    guard let parsedAmount = parseAmount(amount) else {
                        validationError = "Enter a valid Out amount."
                        return
                    }
                    guard dateWasChosen else {
                        validationError = "Choose an Out date."
                        return
                    }
                    let debtDetails: BudgetDebtDetails?
                    if isDebt {
                        guard let details = makeDebtDetails() else { return }
                        debtDetails = details
                    } else {
                        debtDetails = nil
                    }
                    validationError = nil
                    onSave(nextName, parsedAmount, date, frequency, debtDetails)
                    dismiss()
                }
            }
            settingsFieldError(validationError)
        }
        .alert("Delete \(bill?.name ?? "Out")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }

    private var payoffSummary: some View {
        let balance = (Double(currentPrincipal) ?? bill?.debtDetails?.currentPrincipal ?? 0) +
            (Double(accruedInterest) ?? bill?.debtDetails?.accruedInterest ?? 0)
        let payment = Double(amount) ?? bill?.amount ?? 0
        let rate = Double(apr) ?? bill?.debtDetails?.interestRateAPR ?? 0
        let item = DebtOverviewItem(
            id: bill?.id ?? "draft",
            name: name,
            startingBalance: Double(startingBalance) ?? bill?.debtDetails?.startingBalance ?? 0,
            currentPrincipal: Double(currentPrincipal) ?? bill?.debtDetails?.currentPrincipal ?? 0,
            accruedInterest: Double(accruedInterest) ?? bill?.debtDetails?.accruedInterest ?? 0,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: rate,
            minimumPayment: Double(minimumPayment) ?? bill?.debtDetails?.minimumPayment ?? 0,
            plannedMonthlyPayment: payment,
            nextPaymentDate: date.ymdString
        )
        let months = DebtOverviewMath.monthsToPayoff(item)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Debt Details")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.floatTextFaint)
                .tracking(0.8)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                detailMetric("Current Debt", money(balance))
                Spacer()
                detailMetric("Debt-Free", debtFreeText(months))
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

    private func debtFreeText(_ months: Int?) -> String {
        guard let months else { return "Not enough" }
        if months == 0 { return "Paid off" }
        let debtFreeDate = Calendar.current.date(byAdding: .month, value: months, to: date) ?? date
        return labelDate(debtFreeDate.ymdString)
    }

    private func makeDebtDetails() -> BudgetDebtDetails? {
        guard let starting = parseAmount(startingBalance) else {
            validationError = "Enter a valid starting balance."
            return nil
        }
        guard let principal = parseAmount(currentPrincipal) else {
            validationError = "Enter a valid current principal."
            return nil
        }
        guard let interest = parseAmount(accruedInterest) else {
            validationError = "Enter valid accrued interest."
            return nil
        }
        guard let rate = parseAmount(apr) else {
            validationError = "Enter a valid interest rate."
            return nil
        }
        guard let minimum = parseAmount(minimumPayment) else {
            validationError = "Enter a valid required minimum."
            return nil
        }

        return BudgetDebtDetails(
            startingBalance: starting,
            currentPrincipal: principal,
            accruedInterest: interest,
            balanceDate: balanceDate.ymdString,
            interestRateAPR: rate,
            minimumPayment: minimum
        )
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
        EditorShell(accountColor: accountColor, title: income == nil ? "New In" : "Edit In") {
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
                        validationError = "Enter an In name."
                        return
                    }
                    guard let parsedAmount = parseAmount(amount) else {
                        validationError = "Enter a valid In amount."
                        return
                    }
                    guard dateWasChosen else {
                        validationError = "Choose an In date."
                        return
                    }
                    validationError = nil
                    onSave(nextLabel, parsedAmount, date, frequency)
                    dismiss()
                }
            }
            settingsFieldError(validationError)
        }
        .alert("Delete \(income?.label ?? "In")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
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
