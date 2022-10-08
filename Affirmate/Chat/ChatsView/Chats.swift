//
//  Chats.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct Chats: View {
    @EnvironmentObject var chatsObserver: ChatsObserver
    var body: some View {
        ForEach(chatsObserver.chats) { chat in
#if !os(watchOS)
            ChatLabel(chat: chat)
#else
            NavigationLink(value: chat) {
                ChatLabel(chat: chat)
            }
#endif
        }
    }
}

struct Chats_Previews: PreviewProvider {
    static var previews: some View {
        Chats()
    }
}
