//
//  AuthService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/5/26.
//

// Sources/FirebaseKit/AuthService.swift
import FirebaseAuth

public final class AuthService {
    
    public static let shared = AuthService()
    
    private let auth: Auth
    
    private init() {
        self.auth = Auth.auth()
    }
    
    public init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }
    
    // MARK: - Current User
    public var currentUser: User? { auth.currentUser }
    public var isSignedIn: Bool { currentUser != nil }
    public var userID: String? { currentUser?.uid }
    public var userEmail: String? { currentUser?.email }
    public var displayName: String? { currentUser?.displayName }
    
    // MARK: - Email & Password
    public func signIn(email: String, password: String) async throws -> User {
        let result = try await auth.signIn(withEmail: email, password: password)
        return result.user
    }
    
    public func signUp(email: String, password: String) async throws -> User {
        let result = try await auth.createUser(withEmail: email, password: password)
        return result.user
    }
    
    public func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    public func updatePassword(newPassword: String) async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        try await user.updatePassword(to: newPassword)
    }
    
    public func updateEmail(newEmail: String) async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        try await user.sendEmailVerification(beforeUpdatingEmail: newEmail)
    }
    
    public func updateDisplayName(_ name: String) async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }
    
    public func updatePhotoURL(_ url: URL) async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.photoURL = url
        try await changeRequest.commitChanges()
    }
    
    // MARK: - Email Verification
    public func sendEmailVerification() async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        try await user.sendEmailVerification()
    }
    
    public var isEmailVerified: Bool {
        currentUser?.isEmailVerified ?? false
    }
    
    // MARK: - Google Sign-In
    /// Pass in the ID token and access token from GoogleSignIn SDK
    public func signInWithGoogle(idToken: String, accessToken: String) async throws -> User {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await auth.signIn(with: credential)
        return result.user
    }
    
    // MARK: - Apple Sign-In
    /// Pass in the token and nonce from ASAuthorizationAppleIDCredential
    public func signInWithApple(idToken: String, nonce: String) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        let result = try await auth.signIn(with: credential)
        return result.user
    }
    
    // MARK: - Phone Number
    /// Step 1 - send verification code to phone number e.g. "+11234567890"
    public func sendPhoneVerification(phoneNumber: String) async throws -> String {
        let verificationID = try await PhoneAuthProvider.provider()
            .verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        return verificationID
    }
    
    /// Step 2 - sign in with the verification ID from step 1 and the code the user received
    public func signInWithPhone(verificationID: String, verificationCode: String) async throws -> User {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        let result = try await auth.signIn(with: credential)
        return result.user
    }
    
    // MARK: - Anonymous
    public func signInAnonymously() async throws -> User {
        let result = try await auth.signInAnonymously()
        return result.user
    }
    
    /// Link anonymous account to email so they don't lose their data
    public func linkAnonymousAccount(email: String, password: String) async throws -> User {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        let result = try await user.link(with: credential)
        return result.user
    }
    
    // MARK: - Account Management
    public func deleteAccount() async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        try await user.delete()
    }
    
    public func reAuthenticate(email: String, password: String) async throws {
        guard let user = currentUser else { throw AuthError.notSignedIn }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        try await user.reauthenticate(with: credential)
    }
    
    public func signOut() throws {
        try auth.signOut()
    }
    
    // MARK: - Auth State Listener
    public func addAuthStateListener(_ listener: @escaping (User?) -> Void) -> AuthStateDidChangeListenerHandle {
        auth.addStateDidChangeListener { _, user in
            listener(user)
        }
    }
    
    public func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        auth.removeStateDidChangeListener(handle)
    }
}

// MARK: - AuthError
public enum AuthError: LocalizedError {
    case notSignedIn
    
    public var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "No user is currently signed in."
        }
    }
}
