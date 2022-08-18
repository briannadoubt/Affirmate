//
//  ContentView.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var authentication = Authentication()
    
    var body: some View {
        switch authentication.state {
        case .initial:
            ProgressView()
                .task {
                    await authentication.setCurrentAuthenticationState()
                }
        case .loading:
            ProgressView()
        case .loggedOut:
            AuthenticationView()
                .environmentObject(authentication)
        case .loggedIn:
            AffirmateTabView()
                .environmentObject(authentication)
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
