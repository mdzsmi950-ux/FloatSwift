import SwiftUI

struct OnboardingView: View {
    var isDemoMode: Bool
    var onFinish: () -> Void

    @State private var pageIndex = 0

    private var pages: [OnboardingPage] {
        [
        OnboardingPage(
            title: "Are you floating?",
            body: [
                "Categories never really helped me.",
                "The real question is: will I make it to my next paycheck?"
            ]
        ),
        OnboardingPage(
            title: "Timing matters",
            body: [
                "Enter your income and outgoing payments.",
                "Float shows what your balance should look like after money comes in and payments go out."
            ]
        ),
        OnboardingPage(
            title: "Let’s see an example",
            body: [
                "The screen behind this guide shows Maddie and Nick’s sample budget.",
                "Use the account switcher in the bottom bar to switch between accounts.",
                "The reserve bar shows how much emergency fund has been built and how much is still left to go."
            ]
        ),
        OnboardingPage(
            title: "Now check In and Out",
            body: [
                "In is where income is added, and Out is where bills, cards, debts, transfers, and other outgoing payments are built.",
                "Settings keeps accounts, balance, reserve, and general controls like backup, palette, app lock, and onboarding.",
                isDemoMode
                    ? "When you are done with the demo, tap Start Yours to erase the sample budget and start your own."
                    : "You can return to your budget without changing or erasing anything."
            ]
        )
        ]
    }

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    var body: some View {
        onboardingCard
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageContent
                .gesture(
                        DragGesture(minimumDistance: 22)
                            .onEnded { value in
                                if value.translation.width < -45 {
                                    goNext(allowFinish: false)
                                } else if value.translation.width > 45 {
                                    goBack()
                                }
                        }
                )

            HStack(spacing: 7) {
                ForEach(pages.indices, id: \.self) { index in
                    Button {
                        withTransaction(noAnimationTransaction) {
                            pageIndex = index
                        }
                    } label: {
                        Capsule()
                            .fill(index == pageIndex ? Color.floatText : .black.opacity(0.18))
                            .frame(width: index == pageIndex ? 22 : 7, height: 7)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
            .padding(.bottom, 18)

            HStack(spacing: 10) {
                if pageIndex > 0 {
                        Button("Back", action: goBack)
                        .buttonStyle(OnboardingButtonStyle(kind: .secondary))
                        .frame(width: 92)
                }

                Button(isLastPage ? finishTitle : "Next") {
                    goNext(allowFinish: true)
                }
                    .buttonStyle(OnboardingButtonStyle(kind: .primary))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(.white.opacity(0.84))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(.black.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 18)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(pages[pageIndex].title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.floatText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if pageIndex == pages.count - 1 {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.floatText)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.black.opacity(0.08), lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(pages[pageIndex].body, id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.system(size: 16))
                        .lineSpacing(4)
                        .foregroundStyle(Color.floatTextMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .contentShape(Rectangle())
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func goNext(allowFinish: Bool) {
        withTransaction(noAnimationTransaction) {
            if isLastPage {
                if allowFinish {
                    onFinish()
                }
            } else {
                pageIndex = min(pageIndex + 1, pages.count - 1)
            }
        }
    }

    private func goBack() {
        withTransaction(noAnimationTransaction) {
            pageIndex = max(pageIndex - 1, 0)
        }
    }

    private var noAnimationTransaction: Transaction {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        return transaction
    }

    private var finishTitle: String {
        isDemoMode ? "Explore Demo" : "Done"
    }
}

private struct OnboardingPage {
    var title: String
    var body: [String]
}

private struct OnboardingButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(kind == .primary ? .white : Color.floatText)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(kind == .primary ? Color.floatText : .white.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.black.opacity(kind == .primary ? 0 : 0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(kind == .primary ? 0.14 : 0), radius: 14, y: 8)
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}
