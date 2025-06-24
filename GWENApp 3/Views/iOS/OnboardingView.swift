import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            Text("Welcome to GWEN!")
                .font(.largeTitle)
            
            Button("Get Started") {
                appState.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

