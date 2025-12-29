//
//  AppDelegate.swift
//  Affirmate
//
//  Created by Bri on 8/21/22.
//

import SwiftUI

extension Notification.Name {
    static let backgroundNotificationReceived = Notification.Name("backgroundNotificationReceived")
}

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var deviceToken: Data?
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.deviceToken = deviceToken
    }
    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        print(userInfo)
    }
}

#else

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    
    static var deviceToken: Data?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    // No callback in simulator
    // -- must use device to get valid push token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.deviceToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) async -> UIBackgroundFetchResult {
        print("Received remote notification:", userInfo)
        switch application.applicationState {
        case .active:
            // App is in foreground - notification will be handled by the active view
            return .noData
        case .background:
            guard
                let aps = userInfo["aps"] as? [AnyHashable: Any],
                let contentAvailable = aps["content-available"] as? Int,
                contentAvailable == 1
            else {
                return .noData
            }
            // Background notification received - trigger data refresh
            // The app will sync new messages when it becomes active
            NotificationCenter.default.post(name: .backgroundNotificationReceived, object: userInfo)
            return .newData
        case .inactive:
            // App is transitioning states
            return .noData
        @unknown default:
            return .noData
        }
    }
}
#endif
