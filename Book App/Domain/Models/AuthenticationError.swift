import Foundation

enum AuthenticationError: Error {
    case invalidEmail, invalidCredentials, emailInUse, passwordPolicy, offline, throttled, disabled, unavailable, emailChangeUnavailable, unknown

    var message: String {
        switch self {
        case .invalidEmail: String(localized: "Enter a valid email address.")
        case .invalidCredentials: String(localized: "That email or password isn’t right. Please try again.")
        case .emailInUse: String(localized: "An account already uses this email. Try logging in.")
        case .passwordPolicy: String(localized: "This password doesn’t meet the account password requirements. Try a longer password with uppercase and lowercase letters, a number, and a symbol.")
        case .offline: String(localized: "Unable to connect. Check your internet connection and try again.")
        case .throttled: String(localized: "Too many attempts. Please wait a while before trying again.")
        case .disabled: String(localized: "This account is unavailable. Please contact support.")
        case .unavailable: String(localized: "Email login is currently unavailable. Please contact support.")
        case .emailChangeUnavailable: String(localized: "Email changes are currently unavailable. Please contact support.")
        case .unknown: String(localized: "We couldn’t complete that request. Please try again.")
        }
    }
}
