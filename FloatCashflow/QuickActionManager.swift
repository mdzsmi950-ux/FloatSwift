import SwiftUI
import UIKit

enum FloatQuickAction: Equatable {
    case editBalance(accountId: String)
    case status(accountId: String)
}

@MainActor
final class QuickActionManager: ObservableObject {
    static let shared = QuickActionManager()

    @Published var pendingAction: FloatQuickAction?

    private let editBalanceType = "com.maddie.floatapp.editBalance"
    private let statusType = "com.maddie.floatapp.status"
    private let accountIdKey = "accountId"
    private let pendingTypeKey = "float:pendingQuickActionType"
    private let pendingAccountIdKey = "float:pendingQuickActionAccountId"

    private init() {}

    func updateShortcutItems(for budget: FloatBudget) {
        var items: [UIApplicationShortcutItem] = []

        for account in budget.accounts.prefix(2) {
            items.append(UIApplicationShortcutItem(
                type: editBalanceType,
                localizedTitle: "Edit \(account.name) Balance",
                localizedSubtitle: money(account.currentBalance),
                icon: UIApplicationShortcutIcon(systemImageName: "dollarsign.circle"),
                userInfo: [accountIdKey: account.id as NSString]
            ))
        }

        items.append(statusItem(for: budget))

        UIApplication.shared.shortcutItems = items
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) {
        guard let accountId = shortcutItem.userInfo?[accountIdKey] as? String ??
                (shortcutItem.userInfo?[accountIdKey] as? NSString).map(String.init) else {
            return
        }

        switch shortcutItem.type {
        case editBalanceType:
            setPendingAction(.editBalance(accountId: accountId))
        case statusType:
            setPendingAction(.status(accountId: accountId))
        default:
            break
        }
    }

    func consumePendingAction() -> FloatQuickAction? {
        if let pendingAction {
            clearPendingAction()
            return pendingAction
        }

        guard let type = UserDefaults.standard.string(forKey: pendingTypeKey),
              let accountId = UserDefaults.standard.string(forKey: pendingAccountIdKey) else {
            return nil
        }

        clearPendingAction()

        switch type {
        case editBalanceType:
            return .editBalance(accountId: accountId)
        case statusType:
            return .status(accountId: accountId)
        default:
            return nil
        }
    }

    func clearPendingAction() {
        pendingAction = nil
        UserDefaults.standard.removeObject(forKey: pendingTypeKey)
        UserDefaults.standard.removeObject(forKey: pendingAccountIdKey)
    }

    private func statusItem(for budget: FloatBudget) -> UIApplicationShortcutItem {
        let statuses = budget.accounts.map { account in
            let events = BudgetMath.buildEvents(account: account, cutoff: BudgetMath.cutoff())
            return (
                account: account,
                sinkingDate: BudgetMath.sinkingDate(startingBalance: account.currentBalance, events: events)
            )
        }
        let sinkingStatuses = statuses
            .compactMap { item -> (account: FloatAccount, sinkingDate: String)? in
                guard let sinkingDate = item.sinkingDate else { return nil }
                return (item.account, sinkingDate)
            }
            .sorted { $0.sinkingDate < $1.sinkingDate }
        let title: String
        let subtitle: String
        let accountId: String

        if budget.accounts.count == 1, let account = budget.accounts.first {
            accountId = account.id
            if let sinkingDate = sinkingStatuses.first?.sinkingDate {
                title = "\(account.name) Sinking \(labelDate(sinkingDate))"
                subtitle = "Open timeline"
            } else {
                title = "\(account.name) Floating"
                subtitle = "Open timeline"
            }
        } else if let firstSinking = sinkingStatuses.first {
            accountId = firstSinking.account.id
            if sinkingStatuses.count == 1 {
                title = "\(firstSinking.account.name) Sinking \(labelDate(firstSinking.sinkingDate))"
                subtitle = "Open timeline"
            } else {
                title = "\(sinkingStatuses.count) Accounts Sinking"
                subtitle = "Earliest: \(firstSinking.account.name) \(labelDate(firstSinking.sinkingDate))"
            }
        } else {
            accountId = budget.widgetAccount?.id ?? budget.accounts.first?.id ?? FloatBudget.blank.accounts[0].id
            title = budget.accounts.count == 2 ? "Both Accounts Floating" : "All Accounts Floating"
            subtitle = "Open timeline"
        }

        return UIApplicationShortcutItem(
            type: statusType,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(systemImageName: "chart.line.uptrend.xyaxis"),
            userInfo: [accountIdKey: accountId as NSString]
        )
    }

    private func setPendingAction(_ action: FloatQuickAction) {
        pendingAction = action

        switch action {
        case .editBalance(let accountId):
            UserDefaults.standard.set(editBalanceType, forKey: pendingTypeKey)
            UserDefaults.standard.set(accountId, forKey: pendingAccountIdKey)
        case .status(let accountId):
            UserDefaults.standard.set(statusType, forKey: pendingTypeKey)
            UserDefaults.standard.set(accountId, forKey: pendingAccountIdKey)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let shortcutItem = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            Task { @MainActor in
                QuickActionManager.shared.handle(shortcutItem)
            }
            return false
        }

        return true
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            QuickActionManager.shared.handle(shortcutItem)
            completionHandler(true)
        }
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            Task { @MainActor in
                QuickActionManager.shared.handle(shortcutItem)
            }
        }
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            QuickActionManager.shared.handle(shortcutItem)
            completionHandler(true)
        }
    }
}
