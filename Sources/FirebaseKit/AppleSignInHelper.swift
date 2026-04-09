//
//  AppleSignInHelper.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/9/26.
//

// Sources/FirebaseKit/AppleSignInHelper.swift
import AuthenticationServices
import CryptoKit
import FirebaseAuth

public struct AppleSignInHelper {
    
    public static var currentNonce: String?
    
    public static func randomNonceString() -> String {
        let nonce = UUID().uuidString
        currentNonce = nonce
        return sha256(nonce)
    }
    
    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public static func handle(
        _ authorization: ASAuthorization,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else { return }
        
        Task {
            do {
                let user = try await AuthService.shared.signInWithApple(
                    idToken: token,
                    nonce: nonce
                )
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
