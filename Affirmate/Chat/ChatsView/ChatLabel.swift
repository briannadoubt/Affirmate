//
//  ChatLabel.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

struct ChatLabel: View {
    @EnvironmentObject var chatsObserver: ChatsObserver
    var chat: Chat
    var participants: [Participant] {
        (chat.participants?.allObjects as? [Participant]) ?? []
    }
    var participantsLabel: String {
        participants.compactMap({ $0.username }).joined(separator: ", ")
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(participantsLabel)
                .bold()
            HStack {
                if
                    let messages = chat.messages?.allObjects as? [Message],
                    let lastMessage = messages.last,
                    let sender = lastMessage.sender,
                    let username = sender.username,
                    let createdAt = lastMessage.createdAt?.formatted(date: .numeric, time: .shortened) ?? ""
                {
                    Text("Message from " + username + " at " + createdAt)
                } else {
                    Text("No messages yet...")
                }
            }
        }
    }
}

struct ChatLabel_Previews: PreviewProvider {
    static var previews: some View {
        ChatLabel(chat: Chat())
    }
}
