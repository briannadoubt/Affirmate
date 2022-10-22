//
//  ContentView.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var authentication = AuthenticationObserver.shared
    
    var body: some View {
        switch authentication.state {
        case .initial:
            VStack {
                ProgressView()
                Text("Preparing...")
            }
            .task {
                await authentication.setCurrentAuthenticationState()
            }
        case .loading(let message):
            VStack {
                ProgressView()
                Text(message)
            }
        case .loggedOut:
            AuthenticationView()
                .environmentObject(authentication)
        case .loggedIn:
            AffirmateTabView()
                .environmentObject(authentication)
            #if !os(watchOS)
                .task {
                    await AffirmateApp.requestNotificationPermissions()
                    if let token = AppDelegate.deviceToken {
                        do {
                            try await authentication.update(deviceToken: token)
                        } catch {
                            print("Failed to update device token:", error)
                        }
                    }
                }
            #endif
                .task {
                    do {
                        try await authentication.getCurrentUser()
                    } catch {
                        print("Failed to get current user:", error)
                    }
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
