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

public enum SignInWithAppleButtonStyle {
    case white
    case black
    case whiteOutline
    case adaptive
}

public struct AppleSignInButton: View {
    var label: SignInWithAppleButton.Label
    var style: SignInWithAppleButtonStyle
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(label: SignInWithAppleButton.Label, style: SignInWithAppleButtonStyle, onSuccess: ((User) -> Void)? = nil, onFailure: ((Error) -> Void)? = nil) {
        self.label = label
        self.style = style
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    public var appleStyle: SignInWithAppleButton.Style {
        switch style {
        case .white: return .white
        case .black: return .black
        case .whiteOutline: return .whiteOutline
        case .adaptive: return colorScheme == .dark ? .white : .black
        }
    }
    
    public var body: some View {
        ZStack {
            Color.clear
                .frame(height: 50)
            
            SignInWithAppleButton(label) { request in
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
            .signInWithAppleButtonStyle(appleStyle)
            .frame(height: 50)
            .id(colorScheme)
        }
    }
}

public enum GoogleSignInLabel: String {
    case signIn = "Sign in with Google"
    case signUp = "Sign up with Google"
    case `continue` = "Continue with Google"
}

public struct GoogleSignInButton: View {
    
    var label: GoogleSignInLabel
    var foregroundColor: Color
    var backgroundColor: Color
    var onSuccess: ((User) -> Void)?
    var onFailure: ((Error) -> Void)?
    
    public init(
        label: GoogleSignInLabel,
        foregroundColor: Color = .white,
        backgroundColor: Color = .black,
        onSuccess: ((User) -> Void)? = nil,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self.label = label
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
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
            HStack {
                Image("GoogleIcon", bundle: .module)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .padding(.leading, 75)
                Text(label.rawValue)
                    .font(.title3)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth(duration: 0.25), value: configuration.isPressed)
    }
}

#endif
