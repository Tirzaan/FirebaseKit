//
//  CrashlyticsService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/8/26.
//

// Sources/FirebaseKit/CrashlyticsService.swift
import FirebaseCrashlytics

public final class CrashlyticsService {
    
    public static let shared = CrashlyticsService()
    
    private init() {}
    
    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    
    public func record(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
    
    public func setUserID(_ id: String) {
        Crashlytics.crashlytics().setUserID(id)
    }
    
    public func setValue(_ value: Any, for key: String) {
        Crashlytics.crashlytics().setValue(value, forKey: key)
    }
    
    public func resetUser() {
        Crashlytics.crashlytics().setUserID("")
    }
}
