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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [accountColor, accountColor, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                switch selectedTab {
                case .overview:
                    OverviewView(startOwnBudget: {
                        showStartOwnBudgetAlert = true
                    })
                case .settings:
                    SettingsView(
                        goToOverview: { selectedTab = .overview },
                        startOwnBudget: { showStartOwnBudgetAlert = true },
                        privacyLock: privacyLock
                    )
                }
            }

            floatingNavigation

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
                selectedTab = .settings
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

    private var floatingNavigation: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        cycleAccount()
                    } label: {
                        HStack(spacing: 10) {
                            Text(store.activeAccount.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.floatTextMid)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: 108, alignment: .trailing)
                            floatingIcon("arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedTab = selectedTab == .overview ? .settings : .overview
                    } label: {
                        HStack(spacing: 10) {
                            Text(selectedTab == .overview ? "Settings" : "Overview")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.floatTextMid)
                            floatingIcon(selectedTab == .overview ? "gearshape.fill" : "chart.line.uptrend.xyaxis")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
        }
        .zIndex(8)
    }

    private func floatingIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.floatTextMid)
            .frame(width: 48, height: 48)
            .background(.white.opacity(0.72))
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(.black.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
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
    case settings
}

private struct QuickBalanceEditor: View {
    var account: FloatAccount
    var onCancel: () -> Void
    var onConfirm: (Double) -> Void

    @State private var amountText: String
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
                    onCancel()
                }
                .buttonStyle(QuickBalanceButtonStyle(fill: .secondary))

                Button("Confirm") {
                    guard let amount = Double(amountText) else { return }
                    onConfirm(amount)
                }
                .buttonStyle(QuickBalanceButtonStyle(fill: .primary))
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
