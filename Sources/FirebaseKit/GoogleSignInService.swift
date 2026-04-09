//
//  GoogleSignInService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/9/26.
//

// Sources/FirebaseKit/GoogleSignInService.swift
import GoogleSignIn
import FirebaseAuth
import UIKit

public final class GoogleSignInService {
    
    public static let shared = GoogleSignInService()
    
    private init() {}
    
    public func signIn(
        from viewController: UIViewController,
        completion: @escaping (Result<User, Error>) -> Void
    ) {
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
