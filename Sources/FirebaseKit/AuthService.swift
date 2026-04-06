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
    
    public var currentUser: User? { Auth.auth().currentUser }
    public var isSignedIn: Bool { currentUser != nil }
    
    private init() {}
    
    public func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }
    
    public func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }
    
    public func signOut() throws {
        try Auth.auth().signOut()
    }
}
