import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BudgetStore
    @State private var selectedTab: AppTab = .overview
    @State private var showOnboarding =
        !UserDefaults.standard.bool(forKey: AppStorageKey.onboardingComplete) ||
        UserDefaults.standard.bool(forKey: AppStorageKey.demoMode)
    @State private var showStartOwnBudgetAlert = false

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
                        startOwnBudget: { showStartOwnBudgetAlert = true }
                    )
                }
            }

            if selectedTab == .overview {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            selectedTab = .settings
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.floatTextMid)
                                .frame(width: 58, height: 58)
                                .background(.white.opacity(0.72))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(.black.opacity(0.08), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }

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
        }
        .alert("Start Your Own Budget?", isPresented: $showStartOwnBudgetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Erase Demo", role: .destructive) {
                store.startOwnBudget()
                selectedTab = .settings
                showOnboarding = false
            }
        } message: {
            Text("This will erase the sample budget and let you start with your own information.")
        }
    }
}

private enum AppTab {
    case overview
    case settings
}
