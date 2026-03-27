import Foundation

enum AuthMode: CaseIterable {
    case login
    case signup

    var title: String {
        switch self {
        case .login:
            return "Login"
        case .signup:
            return "Sign Up"
        }
    }
}
