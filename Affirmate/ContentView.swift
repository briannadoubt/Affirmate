//
//  ContentView.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var authentication = AuthenticationObserver()
    
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
                            print("TODO: Show this error in the UI:", error)
                        }
                    }
                }
            #endif
                .task {
                    do {
                        try await authentication.getCurrentUser()
                    } catch {
                        print("TODO: Show this error in the UI:", error)
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
