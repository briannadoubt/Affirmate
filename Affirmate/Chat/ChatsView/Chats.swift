//
//  Chats.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct Chats: View {
    var chats: [Chat]
    var body: some View {
        ForEach(chats) { chat in
            #if !os(watchOS)
            ChatLabel(chat: chat)
                .tag(chat)
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
        Chats(chats: [])
    }
}
