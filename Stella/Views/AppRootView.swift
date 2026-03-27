import SwiftUI
import FirebaseAuth

struct AppRootView: View {
    @State private var currentUser: User? = Auth.auth().currentUser
    @State private var authHandle: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            if currentUser == nil {
                AuthScreenView()
            } else {
                ARAstronomyView()
            }
        }
        .onAppear {
            authHandle = Auth.auth().addStateDidChangeListener { _, user in
                currentUser = user
            }
        }
        .onDisappear {
            if let authHandle {
                Auth.auth().removeStateDidChangeListener(authHandle)
            }
        }
    }
}

#Preview {
    AppRootView()
}
