//
//  MessageView.swift
//  Affirmate
//
//  Created by Bri on 1/14/22.
//

import SwiftUI

public struct MessageView: View {
    
    init(currentParticipantId: UUID, withTail: Bool = false, message: Message) {
        self.currentParticipantId = currentParticipantId
        self.message = message
        self.hasTail = withTail
    }
    
    let currentParticipantId: UUID
    let message: Message
    let hasTail: Bool
    
    var tailPosition: MessageBubbleTailPosition {
        if !hasTail {
            return .none
        }
        return message.sender.id == currentParticipantId ? .rightBottomTrailing : .leftBottomLeading
    }
    
    public var body: some View {
        HStack {
            if message.sender.id == currentParticipantId {
                Spacer(minLength: 64)
            }
            MessageBubble(
                text: message.text ?? "",
                isSender: message.sender.id == currentParticipantId,
                tailPosition: tailPosition
            )
            if message.sender.id != currentParticipantId {
                Spacer(minLength: 64)
            }
        }
        .animation(.spring(), value: message.sender.id == currentParticipantId)
        .transition(.move(edge: message.sender.id == currentParticipantId ? .leading : .trailing).combined(with: .opacity))
        .flipsForRightToLeftLayoutDirection(true)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(
            currentParticipantId: UUID(),
            message: Message(
                id: UUID(),
                text: "Meow",
                chat: Chat.MessageResponse(id: UUID()),
                sender: Participant.GetResponse(
                    id: UUID(),
                    role: .participant,
                    user: AffirmateUser.Public(
                        id: UUID(),
                        username: "Meowface"
                    ),
                    chat: Chat.ParticipantResponse(id: UUID())
                )
            )
        )
    }
}
