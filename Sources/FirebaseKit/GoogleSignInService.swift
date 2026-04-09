//
//  GoogleSignInService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/9/26.
//

// Sources/FirebaseKit/GoogleSignInService.swift
import GoogleSignIn
import FirebaseCore
import FirebaseAuth
import UIKit

public final class GoogleSignInService {
    
    public static let shared = GoogleSignInService()
    
    private init() {}
    
    public func signIn(
        from viewController: UIViewController,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
        // Add this block
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            completion(.failure(NSError(domain: "GoogleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Firebase not configured"])))
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Rest stays the same
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard
                let user = result?.user,
                let idToken = user.idToken?.tokenString
            else { return }
            
            Task {
                do {
                    let firebaseUser = try await AuthService.shared.signInWithGoogle(
                        idToken: idToken,
                        accessToken: user.accessToken.tokenString
                    )
                    completion(.success(firebaseUser))
                } catch {
                    completion(.failure(error))
                }
            }
        }
    }
    
    public func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
    
    public func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
