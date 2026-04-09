//
//  SignInButtons.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/9/26.
//

// Sources/FirebaseKit/SignInButtons.swift
#if canImport(UIKit)
import SwiftUI
import AuthenticationServices
import GoogleSignIn
import FirebaseAuth

public struct AppleSignInButton<T>: View {
    
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(
        onSuccess: ((User) -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInHelper.randomNonceString()
        } onCompletion: { result in
            if case .success(let auth) = result {
                AppleSignInHelper.handle(auth) { result in
                    switch result {
                    case .success(let user): onSuccess?(user)
                    case .failure(let error): onFailure?(error)
                    }
                }
            } else if case .failure(let error) = result {
                onFailure?(error)
            }
        }
        .frame(height: 50)
    }
}

public struct GoogleSignInButton: View {
    
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(
        onSuccess: ((User) -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    public var body: some View {
        Button {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = scene.windows.first?.rootViewController else { return }
            
            GoogleSignInService.shared.signIn(from: rootVC) { result in
                switch result {
                case .success(let user): onSuccess?(user)
                case .failure(let error): onFailure?(error)
                }
            }
        } label: {
            Text("Sign in with Google")
                .font(.system(size: 16, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white)
                .foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

@available(iOS 13.0.0, *)
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth(duration: 0.25), value: configuration.isPressed)
    }
}

#endif
