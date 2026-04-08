//
//  AnalyticsService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/8/26.
//

// Sources/FirebaseKit/AnalyticsService.swift
import FirebaseAnalytics

public final class AnalyticsService {
    
    public static let shared = AnalyticsService()
    
    private init() {}
    
    public init(_ analytics: Analytics.Type = Analytics.self) {}
    
    // MARK: - Screen Tracking
    public func logScreen(name: String, class screenClass: String = "") {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass
        ])
    }
    
    // MARK: - Events
    public func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        Analytics.logEvent(name, parameters: parameters)
    }
    
    // MARK: - User
    public func setUserID(_ id: String) {
        Analytics.setUserID(id)
    }
    
    public func setUserProperty(_ value: String, for name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
    
    public func resetUser() {
        Analytics.setUserID(nil)
    }
    
    // MARK: - Common Events
    public func logSignUp(method: String) {
        Analytics.logEvent(AnalyticsEventSignUp, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
    
    public func logLogin(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [
            AnalyticsParameterMethod: method
        ])
    }
    
    public func logSearch(term: String) {
        Analytics.logEvent(AnalyticsEventSearch, parameters: [
            AnalyticsParameterSearchTerm: term
        ])
    }
    
    public func logSelectContent(type: String, id: String) {
        Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
            AnalyticsParameterContentType: type,
            AnalyticsParameterItemID: id
        ])
    }
}

// Usage
/*
 // Track a screen
 AnalyticsService.shared.logScreen(name: "SignUp")

 // Track sign up
 AnalyticsService.shared.logSignUp(method: "email")

 // Track login
 AnalyticsService.shared.logLogin(method: "google")

 // Track a custom event
 AnalyticsService.shared.logEvent("tribe_selected", parameters: [
     "tribe_name": selectedTribe
 ])

 // Set user info after sign in
 AnalyticsService.shared.setUserID(AuthService.shared.userID ?? "")
 AnalyticsService.shared.setUserProperty("Student", for: "role")

 // Clear user on sign out
 AnalyticsService.shared.resetUser()
 */
