//
//  AffirmateApp.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import SwiftUI

@main
struct AffirmateApp: App {
    
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    static func requestNotificationPermissions() async {
        // MARK: Request permissions to send notifications
        do {
            try await UNUserNotificationCenter.current().requestAuthorization()
        } catch {
            print("TODO: Handle notification authorization failure:", error)
        }
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
