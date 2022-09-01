//
//  MessageView.swift
//  Affirmate
//
//  Created by Bri on 1/14/22.
//

import SwiftUI

public struct MessageView: View {
    
    init(currentUserId: UUID, withTail: Bool = false, message: Message) {
        self.currentUserId = currentUserId
        self.message = message
        self.hasTail = withTail
    }
    
    let currentUserId: UUID
    let message: Message
    let hasTail: Bool
    
    var tailPosition: MessageBubbleTailPosition {
        if !hasTail {
            return .none
        }
        return message.sender.id == currentUserId ? .rightBottomTrailing : .leftBottomLeading
    }
    
    public var body: some View {
        HStack {
            if message.sender.id == currentUserId {
                Spacer(minLength: 64)
            }
            MessageBubble(
                text: message.text,
                isSender: message.sender.id == currentUserId,
                tailPosition: tailPosition
            )
            if message.sender.id != currentUserId {
                Spacer(minLength: 64)
            }
        }
        .animation(.spring(), value: message.sender.id == currentUserId)
        .transition(.move(edge: message.sender.id == currentUserId ? .leading : .trailing).combined(with: .opacity))
        .flipsForRightToLeftLayoutDirection(true)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(
            currentUserId: UUID(),
            message: Message(
                text: "Meow",
                chat: Relation(id: UUID()),
                sender: User(
                    id: UUID(),
                    firstName: "meow",
                    lastName: "face",
                    username: "meowface",
                    email: "meow@fake.com"
                )
            )
        )
    }
}
