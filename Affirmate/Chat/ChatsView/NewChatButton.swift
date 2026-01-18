//
//  NewChatButton.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct NewChatButton: View {
    @Environment(ChatsObserver.self) private var chatsObserver
    @Environment(AuthenticationObserver.self) private var authenticationObserver
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    var body: some View {
        Button(action: { isShowingNewChat.toggle() }) {
            Label("New Chat", systemImage: "plus")
        }
        .popover(isPresented: $isShowingNewChat) {
            NewChatView(isPresented: $isShowingNewChat)
                .environment(chatsObserver)
                .environment(authenticationObserver)
        }
    }
}

struct NewChatButton_Previews: PreviewProvider {
    static var previews: some View {
        NewChatButton()
    }
}
