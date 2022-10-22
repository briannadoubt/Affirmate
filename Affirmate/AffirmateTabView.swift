//
//  AffirmateTabView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

enum DeepLink: String {
    case chat = "chat"
}

struct AffirmateTabView: View {
    @SceneStorage("tabSelection") var tabSelection: TabSelection = .home
    @EnvironmentObject var authentication: AuthenticationObserver
    enum TabSelection: String {
        case home
        case chat
        case me
    }
    var body: some View {
        TabView(selection: $tabSelection) {
            HomeView()
                .tag(TabSelection.home)
                .tabItem {
                    Label("Home", systemImage: tabSelection == .home ? "house.fill" : "house")
                }
            if let currentUserId = authentication.currentUser?.id {
                ChatsView(currentUserId: currentUserId)
                    .tag(TabSelection.chat)
                    .tabItem {
                        Label("Chat", systemImage: tabSelection == .chat ? "message.fill" : "message")
                    }
            }
            MeView()
                .tag(TabSelection.me)
                .tabItem {
                    Label("Me", systemImage: tabSelection == .me ? "person.fill" : "person")
                }
        }
        .onOpenURL { url in
            guard
                let firstPathComponent = url.pathComponents.first,
                let deepLink = DeepLink(rawValue: firstPathComponent)
            else {
                return
            }
            switch deepLink {
            case .chat:
                tabSelection = .chat
            }
        }
    }
}

struct AffirmateTabView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmateTabView()
    }
}
