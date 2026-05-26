# Float Cashflow

Float Cashflow is a native iOS app for short term cash flow planning.

It answers one practical question:

Will my current balance carry me to the next paycheck?

Float is not a bank dashboard, transaction tracker, investment app, or traditional budget app. It is a forward looking cash flow timeline. The app helps users enter their current balance, recurring income, recurring bills, and reserve goal, then see whether they are floating or sinking before the next income event.

## Current version

This repository contains the native Swift version of Float Cashflow.

The earlier versions of this project were built in React, Next.js, Supabase, localStorage, and Capacitor. This version moves the core Float experience into SwiftUI with local native storage, native file backup, and a simpler iOS first interface.

## Product purpose

Most budgeting tools focus on categories, spending history, bank sync, and monthly reports. Float focuses on timing.

A user may have enough money in theory, but still feel unsure because bills and paychecks arrive on different dates. Float turns that uncertainty into a timeline.

The app is designed around:

1. Current account balance
2. Next income date
3. Upcoming bills
4. Reserve balance
5. Whether the projected balance goes below zero

## Core experience

A user starts with a demo budget, then taps Let's Go to begin their own setup.

The intended setup order is:

1. Add first income, such as a paycheck
2. Add fixed bills
3. Confirm current balance
4. Review the timeline
5. Adjust reserve balance and reserve goal if needed

The app then shows whether the user is floating or sinking.

## Main features

### Cash flow timeline

Float builds a future timeline from the user's confirmed balance, income items, and bill items. The timeline groups bills around income events so the user can see what happens between paychecks.

### Floating or sinking status

If the projected running balance goes below zero, the app shows a sinking warning with the date. If the balance remains above zero, the app shows Floating.

### Multiple accounts

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

### Paid early handling

When a bill is marked paid early, Float immediately reduces the current balance and prevents the original future occurrence from appearing again in the timeline.

### Reserve tracking

Each account has a reserve balance and reserve goal. Float shows reserve progress in the overview.

### Transfer to reserve

A bill named Transfer to Reserve is treated as a reserve transfer. When it becomes due, Float can apply it to the account's reserve balance and track that it has already been applied.

### Backup and import

Float stores the user's budget locally and supports JSON backup export and import. The backup contains the budget data only. App settings such as palette choice, onboarding state, privacy lock settings, and backup dates should remain outside the backup file.

### Demo mode

The app includes a demo budget so new users can understand the timeline before entering their own data. Demo mode ends only when the user taps Let's Go and confirms that they want to erase the sample budget.

### Account palettes

Users can choose from preset account palettes:

1. Original
2. Bright
3. Fall and winter
4. White
5. Color safe

The palette affects account background colors and account markers.

### Legacy migration

The Swift version includes migration logic for older local Float data. The previous local web version stored budget data in WebView localStorage under the key `float_budget_v1`. The Swift app attempts to recover old local data through native container file scanning and a hidden WebView localStorage probe.

## Data model

The app stores one budget object.

```json
{
  "version": 1,
  "activeAccountId": "personal",
  "accounts": []
}
