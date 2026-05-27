# Float Cashflow

Float Cashflow is a native SwiftUI cash-flow app for answering one practical question: will this account make it to the next paycheck?

Instead of traditional budget categories, Float builds a forward-looking timeline from a confirmed cash balance, recurring income, bills, card payments, debts, and reserve savings. The app is designed for quick daily use: confirm the balance, check the timeline, and see whether the account is floating or sinking.

## Current Features

- Multiple cash-flow accounts
- Confirmed/current balance tracking
- Forward cash-flow timeline
- Income, bills, cards, and long-term debt entries
- Paid-early bill handling
- Sinking date calculation
- Reserve balance and reserve goal tracking
- First-run onboarding with demo budget
- First setup guide for new user budgets
- Local JSON persistence
- Backup export and import
- Debt payoff planning tool
- App lock with Face ID/passcode support
- Home screen quick actions
- iOS widget support through an app group snapshot
- Color palette settings

## App Structure

The main app code lives in `FloatCashflow/`.

Key files:

- `FloatCashflowApp.swift` starts the app and injects `BudgetStore`.
- `ContentView.swift` handles top-level navigation, onboarding, app lock overlay, quick actions, and legacy migration probing.
- `Models.swift` defines the core budget, account, bill, income, debt, and cash event models.
- `BudgetStore.swift` owns the main budget state, persistence, import/export replacement, account updates, balance confirmation, bill/income/debt updates, paid-early handling, and widget snapshot refreshes.
- `BudgetMath.swift` builds the timeline, recurrence dates, sinking date calculation, and reserve percentage calculation.
- `OverviewView.swift` displays the reserve card and forward timeline.
- `SettingsView.swift` contains Plan, Tools, and Settings sections.
- `SettingsEditors.swift` contains the add/edit sheets for bills, income, accounts, and debts.
- `OnboardingView.swift` contains the first-run onboarding flow.
- `DebtPayoffStore.swift` and `DebtPayoffView.swift` support payoff planning.
- `PrivacyLockStore.swift` and `PrivacyLockView.swift` support app lock.
- `QuickActionManager.swift` supports iOS home screen quick actions.
- `WidgetSnapshot.swift` creates the shared snapshot consumed by the widget.

The widget code lives in `FloatCashflowWidget/`.

## Persistence

The app stores the main budget locally as `float-budget-v1.json` in the app documents directory.

Debt payoff planning data is stored separately as `debt-payoff-v1.json`.

Backup export creates a JSON payload that includes both the main budget and the debt payoff ledger. Importing a backup replaces the current local budget and debt payoff data after confirmation.

## Widget

The app and widget share data through the app group:

`group.com.maddie.floatapp.v1`

The app writes a compact widget snapshot whenever the budget changes. The widget reads that snapshot and displays account status, cash balance, next scheduled items, and whether any account is sinking.

## Development

Open `FloatCashflow.xcodeproj` in Xcode and run the `Float Cashflow` scheme.

Recommended manual test pass before release:

1. Launch fresh install and complete onboarding.
2. Tap `Let's Go` and start a new budget.
3. Confirm balance.
4. Add income.
5. Add a bill or card payment.
6. Add a debt.
7. Verify the Overview timeline.
8. Test a bill due today.
9. Test a paycheck due today.
10. Mark a bill paid early.
11. Export a backup.
12. Import the backup and confirm all accounts, bills, income, reserve, debts, and payoff data restore.
13. Enable app lock and test Face ID/passcode unlock.
14. Select a widget account and verify widget display.
15. Test home screen quick actions.

## Notes

Float Cashflow is intentionally not a full category-based budgeting app. Its core purpose is short-term cash-flow visibility: showing what happens to an account after each paycheck, bill, card payment, debt payment, and transfer-like obligation.