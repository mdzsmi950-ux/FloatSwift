import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var store: BudgetStore
    @StateObject private var privacyLock = PrivacyLockStore()
    @StateObject private var quickActions = QuickActionManager.shared
    @State private var selectedTab: AppTab = .overview
    @State private var showOnboarding =
        !UserDefaults.standard.bool(forKey: AppStorageKey.onboardingComplete) ||
        UserDefaults.standard.bool(forKey: AppStorageKey.demoMode)
    @State private var showStartOwnBudgetAlert = false
    @State private var quickBalanceAccountId: String?

    private var accountColor: Color {
        Color(hex: store.activeAccount.color)
    }

    private var usesOmbreBackground: Bool {
        store.selectedPalette.usesOmbreBackground
    }

    var body: some View {
        ZStack {
            appBackground
            .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(startOwnBudget: {
                        showStartOwnBudgetAlert = true
                    })
                case .plan:
                    SettingsView(
                        mode: .plan,
                        goToOverview: { selectedTab = .overview },
                        startOwnBudget: { showStartOwnBudgetAlert = true },
                        privacyLock: privacyLock
                    )
                case .tools:
                    SettingsView(
                        mode: .tools,
                        goToOverview: { selectedTab = .overview },
                        startOwnBudget: { showStartOwnBudgetAlert = true },
                        privacyLock: privacyLock
                    )
                case .more:
                    SettingsView(
                        mode: .more,
                        goToOverview: { selectedTab = .overview },
                        startOwnBudget: { showStartOwnBudgetAlert = true },
                        privacyLock: privacyLock
                    )
                }
            }

            bottomNavigation

            if showOnboarding {
                VStack {
                    Spacer()
                    OnboardingView {
                        store.finishOnboarding()
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }

            if store.needsLegacyWebMigration {
                LegacyWebStorageProbe { rawValue in
                    store.completeLegacyWebMigration(rawValue: rawValue)
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
            }

            if privacyLock.isLocked {
                PrivacyLockView(privacyLock: privacyLock)
                    .zIndex(20)
            }

            if let quickBalanceAccount {
                Color.black.opacity(0.14)
                    .ignoresSafeArea()
                    .zIndex(12)

                QuickBalanceEditor(
                    account: quickBalanceAccount,
                    onCancel: {
                        quickBalanceAccountId = nil
                        selectedTab = .overview
                    },
                    onConfirm: { amount in
                        store.setActiveAccount(quickBalanceAccount.id)
                        store.confirmBalance(amount)
                        quickBalanceAccountId = nil
                        selectedTab = .overview
                    }
                )
                .zIndex(13)
            }
        }
        .onAppear {
            quickActions.updateShortcutItems(for: store.budget)
            consumePendingQuickAction()
        }
        .onChange(of: store.budget) {
            quickActions.updateShortcutItems(for: store.budget)
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                privacyLock.lockIfNeededAfterGrace()
                quickActions.updateShortcutItems(for: store.budget)
                consumePendingQuickAction()
            } else {
                privacyLock.appDidLeaveActive()
                quickActions.updateShortcutItems(for: store.budget)
            }
        }
        .onChange(of: quickActions.pendingAction) {
            consumePendingQuickAction()
        }
        .onReceive(NotificationCenter.default.publisher(for: .floatReplayOnboarding)) { _ in
            showOnboarding = true
        }
        .alert("Start Your Own Budget?", isPresented: $showStartOwnBudgetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Erase Demo", role: .destructive) {
                store.startOwnBudget()
                selectedTab = .plan
                showOnboarding = false
                NotificationCenter.default.post(name: .floatStartSetup, object: nil)
            }
        } message: {
            Text("This will erase the sample budget and let you start with your own information.")
        }
    }

    private func consumePendingQuickAction() {
        guard let action = quickActions.consumePendingAction() else { return }
        DispatchQueue.main.async {
            handleQuickAction(action)
        }
    }

    private func handleQuickAction(_ action: FloatQuickAction) {
        switch action {
        case .editBalance(let accountId):
            store.setActiveAccount(accountId)
            selectedTab = .overview
            quickBalanceAccountId = accountId
        case .status(let accountId):
            store.setActiveAccount(accountId)
            selectedTab = .overview
        }
    }

    private var quickBalanceAccount: FloatAccount? {
        guard let quickBalanceAccountId else { return nil }
        return store.budget.accounts.first { $0.id == quickBalanceAccountId }
    }

    @ViewBuilder
    private var appBackground: some View {
        if usesOmbreBackground {
            LinearGradient(
                colors: [accountColor, accountColor.opacity(0.42), .white, .white],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            accountColor
        }
    }

    private var bottomNavigation: some View {
        VStack {
            Spacer()
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    bottomTab(
                        title: "Overview",
                        icon: "chart.line.uptrend.xyaxis",
                        isSelected: selectedTab == .overview
                    ) {
                        selectedTab = .overview
                    }

                    Divider()
                        .frame(height: 30)
                        .opacity(0.45)

                    bottomTab(
                        title: "Plan",
                        icon: "list.bullet.rectangle",
                        isSelected: selectedTab == .plan
                    ) {
                        selectedTab = .plan
                    }

                    Spacer()
                        .frame(width: 74)

                    Divider()
                        .frame(height: 30)
                        .opacity(0.45)

                    bottomTab(
                        title: "Tools",
                        icon: "wrench.and.screwdriver",
                        isSelected: selectedTab == .tools
                    ) {
                        selectedTab = .tools
                    }

                    Divider()
                        .frame(height: 30)
                        .opacity(0.45)

                    bottomTab(
                        title: "Settings",
                        icon: "gearshape",
                        isSelected: selectedTab == .more
                    ) {
                        selectedTab = .more
                    }
                }
                .padding(.horizontal, 7)
                .padding(.top, 5)
                .padding(.bottom, 5)
                .frame(height: 54)
                .background(.white.opacity(0.78))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.black.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                .padding(.top, 28)

                accountSwitchBubble
                    .offset(y: 20)
                    .zIndex(2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .zIndex(8)
    }

    private var accountSwitchBubble: some View {
        Button {
            cycleAccount()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                Text(store.activeAccount.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .foregroundStyle(Color.floatText)
            .frame(width: 70, height: 70)
            .background(.white.opacity(0.95))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func bottomTab(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(isSelected ? Color.floatText : Color.floatTextMid)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func cycleAccount() {
        guard store.budget.accounts.count > 1,
              let index = store.budget.accounts.firstIndex(where: { $0.id == store.activeAccount.id }) else { return }
        let next = store.budget.accounts[(index + 1) % store.budget.accounts.count]
        store.setActiveAccount(next.id)
    }
}

extension Notification.Name {
    static let floatStartSetup = Notification.Name("floatStartSetup")
    static let floatFocusBalance = Notification.Name("floatFocusBalance")
    static let floatReplayOnboarding = Notification.Name("floatReplayOnboarding")
}

private enum AppTab {
    case overview
    case plan
    case tools
    case more
}

private struct QuickBalanceEditor: View {
    var account: FloatAccount
    var onCancel: () -> Void
    var onConfirm: (Double) -> Void

    @State private var amountText: String
    @State private var validationError: String?
    @FocusState private var amountIsFocused: Bool

    init(account: FloatAccount, onCancel: @escaping () -> Void, onConfirm: @escaping (Double) -> Void) {
        self.account = account
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _amountText = State(initialValue: account.currentBalance == 0 ? "" : account.currentBalance.formatted(.number.precision(.fractionLength(2))))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(account.name) Balance")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.floatText)

            TextField(money(account.currentBalance), text: $amountText)
                .keyboardType(.decimalPad)
                .focused($amountIsFocused)
                .font(.system(size: 18))
                .foregroundStyle(Color.floatText)
                .tint(Color.floatText)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.floatBorder, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Button("Cancel") {
                    UIApplication.dismissKeyboard()
                    onCancel()
                }
                .buttonStyle(QuickBalanceButtonStyle(fill: .secondary))

                Button("Confirm") {
                    UIApplication.dismissKeyboard()
                    guard let amount = parseAmount(amountText) else {
                        validationError = "Enter a valid balance."
                        return
                    }
                    validationError = nil
                    onConfirm(amount)
                }
                .buttonStyle(QuickBalanceButtonStyle(fill: .primary))
            }

            if let validationError {
                Text(validationError)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.floatWarning)
            }
        }
        .padding(18)
        .frame(maxWidth: 330)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.black.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.16), radius: 24, y: 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                amountIsFocused = true
            }
        }
    }
}

private struct QuickBalanceButtonStyle: ButtonStyle {
    enum Fill {
        case primary
        case secondary
    }

    var fill: Fill

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(fill == .primary ? .white : Color.floatText)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(fill == .primary ? Color.floatText : .white.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.floatBorder, lineWidth: fill == .primary ? 0 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
