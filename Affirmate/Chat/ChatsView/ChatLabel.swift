//
//  ChatLabel.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct ChatLabel: View {
    var chat: Chat
    var body: some View {
        VStack(alignment: .leading) {
            if let lastMessage = Array(chat.messages ?? []).last as? Message {
                Text((lastMessage.sender?.username ?? "") + ": ").bold()
//                Text(lastMessage.text ?? "")
//                    .lineLimit(2)
            } else {
                Text("No messages yet...")
            }
        }
        .tag(chat.id)
    }
}

struct ChatLabel_Previews: PreviewProvider {
    static var previews: some View {
        ChatLabel(chat: Chat())
    }
}
