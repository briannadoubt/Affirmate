//
//  NewChatButton.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct NewChatButton: View {
    @EnvironmentObject var chatsObserver: ChatsObserver
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    var body: some View {
        Button(action: { isShowingNewChat.toggle() }) {
            Label("New Chat", systemImage: "plus")
        }
        .popover(isPresented: $isShowingNewChat) {
            NewChatView(isPresented: $isShowingNewChat)
                .environmentObject(chatsObserver)
                .environmentObject(authenticationObserver)
        }
    }
}

struct NewChatButton_Previews: PreviewProvider {
    static var previews: some View {
        NewChatButton()
    }
}
