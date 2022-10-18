//
//  AppDelegate.swift
//  Affirmate
//
//  Created by Bri on 8/21/22.
//

#if !os(macOS)
import SwiftUI
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
        print(userInfo)
        switch application.applicationState {
        case .active:
            break
        case .background:
            guard
                let aps = userInfo["aps"] as? [AnyHashable: Any],
                let contentAvailable = aps["content-available"] as? String,
                contentAvailable == "1"
            else {
                return .noData
            }
        case .inactive:
            break
        @unknown default:
            assertionFailure()
        }
        return .noData
    }
}
#else
import SwiftUI
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
#endif
