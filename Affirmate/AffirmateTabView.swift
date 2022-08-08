//
//  AffirmateTabView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct AffirmateTabView: View {
    @SceneStorage("tabSelection") var tabSelection: TabSelection = .home
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
            ChatsView()
                .tag(TabSelection.chat)
                .tabItem {
                    Label("Chat", systemImage: tabSelection == .chat ? "message.fill" : "message")
                }
            MeView()
                .tag(TabSelection.me)
                .tabItem {
                    Label("Me", systemImage: tabSelection == .me ? "person.fill" : "person")
                }
        }
    }
}

struct AffirmateTabView_Previews: PreviewProvider {
    static var previews: some View {
        AffirmateTabView()
    }
}
