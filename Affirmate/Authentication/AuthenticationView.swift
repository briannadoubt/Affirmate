//
//  AuthenticationView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import AffirmateShared
import SwiftUI

struct AuthenticationView: View {
    
    @EnvironmentObject var authentication: AuthenticationObserver
    
    var body: some View {
        let scrollView = AuthenticationScrollView()
        let rainbowImage = Image("rainbow")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
        #if os(macOS)
        NavigationView {
            rainbowImage
            scrollView
                .frame(minWidth: 300, idealWidth: 320, maxWidth: 600)
        }
        #else
        ZStack {
            GeometryReader { geometry in
                rainbowImage
                scrollView
                    #if !os(watchOS)
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 600)
                    #endif
                VStack {
                    Color.clear
                        .safeAreaInset(edge: .top) {
                            #if os(watchOS)
                            Color.black
                                .opacity(0.4)
                                .frame(height: geometry.safeAreaInsets.top)
                            #else
                            Color(.systemBackground)
                                .opacity(0.4)
                                .backgroundStyle(.bar)
                                .frame(height: geometry.safeAreaInsets.top)
                            #endif
                        }
                }
                .ignoresSafeArea()
            }
        }
        #endif
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
