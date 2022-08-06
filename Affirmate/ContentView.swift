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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
