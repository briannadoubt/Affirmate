//
//  AffirmateApp.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import UserNotifications
import SwiftUI
import DeviceCheck

@main
struct AffirmateApp: App {
    
    @AppStorage(Constants.UserDefaults.isFirstLaunch) var isFirstLaunch = true
    
    @StateObject var persistence = Persistence()
    
    #if os(iOS) || os(tvOS)
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    #endif
    
    #if os(macOS)
    static func requestNotificationPermissions() async {
        // MARK: Request permissions to send notifications
        do {
            try await UNUserNotificationCenter.current().requestAuthorization()
        } catch {
            print("Failed to request notification center authorization:", error)
        }
        NSApplication.shared.registerForRemoteNotifications()
    }
    #else
    static func requestNotificationPermissions() async {
        // MARK: Request permissions to send notifications
        do {
            try await UNUserNotificationCenter.current().requestAuthorization()
        } catch {
            print("Failed to request notification center authorization:", error)
        }
        #if !os(watchOS)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }
    #endif
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 480, idealHeight: 600)
                #endif
        }
    }
}
