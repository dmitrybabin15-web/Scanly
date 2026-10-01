import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    private let pageSymbols = ["doc.viewfinder", "camera.viewfinder", "infinity"]

    private var pageCount: Int { 3 }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    onboardingPage(0).tag(0)
                    onboardingPage(1).tag(1)
                    onboardingPage(2).tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

                VStack(spacing: 12) {
                    Button(action: advance) {
                        Text(page < pageCount - 1 ? "onboarding_continue" : "onboarding_get_started")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .padding(.top, 8)
                .background(Color(.systemBackground))
            }

            Button("onboarding_skip") {
                onFinish()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func onboardingPage(_ index: Int) -> some View {
        switch index {
        case 0:
            OnboardingPage(title: "onboarding_1_title", detail: "onboarding_1_detail", symbolName: pageSymbols[0])
        case 1:
            OnboardingPage(title: "onboarding_2_title", detail: "onboarding_2_detail", symbolName: pageSymbols[1])
        default:
            OnboardingPage(title: "onboarding_3_title", detail: "onboarding_3_detail", symbolName: pageSymbols[2])
        }
    }

    private func advance() {
        if page < pageCount - 1 {
            withAnimation {
                page += 1
            }
        } else {
            onFinish()
        }
    }
}

private struct OnboardingPage: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbolName: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            Image(systemName: symbolName)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
