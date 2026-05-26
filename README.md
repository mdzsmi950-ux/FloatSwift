# Float Cashflow

Float Cashflow is a native iOS app for short term cash flow planning.

It answers one practical question: will my current balance carry me to the next paycheck?

Float is not a bank dashboard, transaction tracker, investment app, or traditional budgeting app. It is a forward looking cash flow timeline. The app helps users enter their current balance, recurring income, recurring bills, and reserve goal, then see whether they are floating or sinking before the next income event.

## Current Version

This repository contains the native Swift version of Float Cashflow.

Earlier versions of this project were built in React, Next.js, Supabase, localStorage, and Capacitor. This version moves the core Float experience into SwiftUI with local native storage, native file backup, and a simpler iOS first interface.

## Product Purpose

Most budgeting tools focus on categories, spending history, bank sync, and monthly reports. Float focuses on timing.

A user may have enough money in theory, but still feel unsure because bills and paychecks arrive on different dates. Float turns that uncertainty into a timeline.

The app is designed around:

1. Current account balance
2. Next income date
3. Upcoming bills
4. Reserve balance
5. Whether the projected balance goes below zero

## Core Experience

A user starts with a demo budget, then taps Let's Go to begin their own setup.

The intended setup order is:

1. Add first income, such as a paycheck
2. Add fixed bills
3. Confirm current balance
4. Review the timeline
5. Adjust reserve balance and reserve goal if needed

The app then shows whether the user is floating or sinking.

## Main Features

### Cash Flow Timeline

Float builds a future timeline from the user's confirmed balance, income items, and bill items. The timeline groups bills around income events so the user can see what happens between paychecks.

### Floating or Sinking Status

If the projected running balance goes below zero, the app shows a sinking warning with the date. If the balance remains above zero, the app shows Floating.

### Multiple Accounts

Users can create multiple accounts, switch between them, rename them, and delete accounts. Each account has its own balance, bills, income, reserve balance, and reserve goal.

### Bills

Users can add recurring or one time bills. Supported frequencies include:

1. One time
2. Weekly
3. Every two weeks
4. Monthly
5. Quarterly
6. Every six months
7. Annual

Bills can be edited, deleted, and marked as paid early.

### Income

Users can add recurring or one time income items. Income uses the same recurrence system as bills.

### Paid Early Handling

When a bill is marked paid early, Float immediately reduces the current balance and prevents the original future occurrence from appearing again in the timeline.

### Reserve Tracking

Each account has a reserve balance and reserve goal. Float shows reserve progress in the overview.

### Transfer to Reserve

A bill named Transfer to Reserve is treated as a reserve transfer. When it becomes due, Float can apply it to the account's reserve balance and track that it has already been applied.

### Backup and Import

Float stores the user's budget locally and supports JSON backup export and import. The backup contains the budget data only. App settings such as palette choice, onboarding state, privacy lock settings, and backup dates should remain outside the backup file.

### Demo Mode

The app includes a demo budget so new users can understand the timeline before entering their own data. Demo mode ends only when the user taps Let's Go and confirms that they want to erase the sample budget.

### Account Palettes

Users can choose from preset account palettes:

1. Original
2. Bright
3. Fall and winter
4. White
5. Color safe

The palette affects account background colors and account markers.

### Legacy Migration

The Swift version includes migration logic for older local Float data. The previous local web version stored budget data in WebView localStorage under the key `float_budget_v1`. The Swift app attempts to recover old local data through native container file scanning and a hidden WebView localStorage probe.

## Data Model

The app stores one budget object.

```json
{
  "version": 1,
  "activeAccountId": "personal",
  "accounts": []
}
```

Each account contains:

```json
{
  "id": "personal",
  "name": "Personal",
  "color": "EEE9E7",
  "currentBalance": 0,
  "reserveBalance": 0,
  "reserveGoal": 0,
  "lastConfirmedDate": "2026-05-25",
  "bills": [],
  "income": [],
  "paidEarlyBills": [],
  "appliedReserveTransfers": [],
  "balanceIsConfirmed": false
}
```

Bills contain:

```json
{
  "id": "bill-123",
  "name": "Rent",
  "amount": 1200,
  "startDate": "2026-06-01",
  "frequency": "monthly",
  "active": true,
  "linkedTransferId": null
}
```

Income items contain:

```json
{
  "id": "income-123",
  "label": "Paycheck",
  "amount": 2500,
  "startDate": "2026-06-07",
  "frequency": "biweekly",
  "active": true,
  "linkedTransferId": null
}
```

Paid early bills contain:

```json
{
  "id": "early-123",
  "billId": "bill-123",
  "originalDate": "2026-06-01",
  "paidDate": "2026-05-25",
  "amount": 1200
}
```

## Storage

FloatSwift stores the live budget as a JSON file in the app's documents directory:

```text
float-budget-v1.json
```

App state is stored separately in UserDefaults. This includes:

```text
float:onboardingComplete
float:demoMode
float:demoModeEnded
float:lastBackupExportDate
float:lastBackupImportDate
float:legacyMigrationAttempted
float:accountPaletteId
```

## Project Structure

```text
FloatCashflow/
  AccountPalette.swift
  BudgetMath.swift
  BudgetStore.swift
  ContentView.swift
  DemoBudget.swift
  FloatCashflowApp.swift
  Formatters.swift
  LegacyBudgetMigration.swift
  LegacyWebStorageProbe.swift
  Models.swift
  OnboardingView.swift
  OverviewView.swift
  SettingsView.swift
  Assets.xcassets/
```

### BudgetStore.swift

Owns the live budget, app state, storage, import, export, migration, and all major budget mutations.

### BudgetMath.swift

Contains the timeline logic, recurring date logic, sinking date calculation, paid early handling, and reserve transfer detection.

### Models.swift

Defines the Codable budget model, account model, bill model, income model, paid early bill model, and cash event model.

### OverviewView.swift

Displays the account status, reserve card, and cash flow timeline.

### SettingsView.swift

Contains account setup, balance confirmation, bill setup, income setup, reserve setup, palette selection, backup export, and backup import.

### LegacyBudgetMigration.swift

Attempts to recover older Float budget data from app container files.

### LegacyWebStorageProbe.swift

Attempts to recover older Capacitor WebView localStorage data from `capacitor://localhost`.

## Development Requirements

1. macOS
2. Xcode
3. SwiftUI
4. iOS 18.0 or later target

## Running Locally

Open the Xcode project:

```text
FloatCashflow.xcodeproj
```

Select the Float Cashflow target.

Choose an iPhone simulator or connected iPhone.

Run the app from Xcode.

## Backup Format

The backup format is the encoded `FloatBudget` JSON object.

The backup should remain stable because it is the user's escape hatch. Future changes should preserve compatibility whenever possible. If the model changes, decoder defaults should be added so older backup files still import cleanly.

## Design Principles

### Keep the App Narrow

Float should not become a full personal finance dashboard. Features should serve the core purpose of showing whether the user is financially covered until the next income event.

### Prefer Local First

The app does not require bank login. The user owns the data. Backup and import should remain simple and transparent.

### Avoid Category Creep

Float is not primarily about whether spending is Needs, Wants, or Income. The app is about timing and survival between cash events.

### Do Not Hide the Math

The user should be able to understand why the app says they are floating or sinking by looking at the timeline.

### Make Setup Easier, Not More Complex

New features should reduce setup friction or improve trust. They should not add unnecessary configuration.

## Planned Improvements

### Guided Setup

After the user taps Let's Go, the app should jump to Settings and guide the user to add first income. The setup guide should then move through income, bills, and balance confirmation.

### Privacy Lock

Add optional Face ID or 4 to 6 digit app passcode protection. Lock settings should remain in UserDefaults and should not be included in the budget backup.

### Reordering

Allow users to reorder accounts, bills, and income items. Reordering should affect Settings display order and account switching order, but should not affect timeline math.

### Shortcuts

Add basic iOS Shortcuts support for common actions such as opening Float, confirming balance, adding income, adding a bill, or showing the next cash event.

### Today Recap

Add a small recap of today's relevant cash events once the timeline logic is stable.

### Notifications

Add optional local notifications after Today Recap exists. Notification logic should remain calm and limited.

## Project History

This project evolved through several earlier repositories.

```text
float-history-01-budget
float-history-02-finance-dashboard
float-history-03-dashboard-app
float-history-04-float-supabase
float-history-05-float-local
FloatSwift
```

The early versions explored a broader finance dashboard with transactions, categories, balances, archives, bank connection, and net worth. Over time, the project narrowed into a simpler product centered on forward cash flow.

FloatSwift is the current active version.

## Current Status

FloatSwift is the source of truth for the current app.

Older repositories are preserved as archived project history.
