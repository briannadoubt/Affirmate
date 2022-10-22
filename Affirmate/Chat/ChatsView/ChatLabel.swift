//
//  ChatLabel.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct ChatLabel: View {
    var chat: Chat.GetResponse
    var body: some View {
        VStack(alignment: .leading) {
            if let lastMessage = chat.messages?.last {
                Text((lastMessage.sender.user.username) + ": ").bold()
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
        ChatLabel(chat: Chat.GetResponse(id: UUID(), salt: Data()))
    }
}
