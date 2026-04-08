//
//  FCMService.swift
//  FirebaseKit
//
//  Created by Tirzaan on 4/8/26.
//

// Sources/FirebaseKit/FCMService.swift
import FirebaseMessaging
import UserNotifications

public final class FCMService: NSObject {
    
    public static let shared = FCMService()
    
    private override init() {}
    
    public func requestPermission() async throws {
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
        print("Notification permission granted: \(granted)")
    }
    
    public func getToken() async throws -> String {
        return try await Messaging.messaging().token()
    }
    
    public func deleteToken() async throws {
        try await Messaging.messaging().deleteToken()
    }
    
    public func subscribeToTopic(_ topic: String) async throws {
        try await Messaging.messaging().subscribe(toTopic: topic)
    }
    
    public func unsubscribeFromTopic(_ topic: String) async throws {
        try await Messaging.messaging().unsubscribe(fromTopic: topic)
    }
}
