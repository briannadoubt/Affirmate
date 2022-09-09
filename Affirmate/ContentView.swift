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
                .task {
                    await AffirmateApp.requestNotificationPermissions()
                    if let token = AppDelegate.deviceToken {
                        do {
                            try await authentication.refresh(deviceToken: token)
                        } catch {
                            print("TODO: Show this error in the UI:", error)
                        }
                    }
                }
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
