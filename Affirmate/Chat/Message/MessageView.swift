//
//  MessageView.swift
//  Affirmate
//
//  Created by Bri on 1/14/22.
//

import SwiftUI

public struct MessageView: View {
    
    @EnvironmentObject var chatObserver: ChatObserver
    
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
    
    @State private var text: String?
    @State private var swipeOffset = CGSize.zero
    @State private var deviceShouldIndicateSwipeAction = false
    @State private var shouldReply = false
    
    #if os(watchOS)
    private let spacerLength: CGFloat = 24
    #else
    private let spacerLength: CGFloat = 64
    #endif
    
    var isSender: Bool {
        message.sender.id == currentParticipantId
    }
    
    public var body: some View {
        HStack {
            if message.sender.id == currentParticipantId {
                Spacer(minLength: spacerLength)
            }
            if let text = text {
                MessageBubble(
                    text: text,
                    isSender: isSender,
                    tailPosition: tailPosition
                )
            }
            if message.sender.id != currentParticipantId {
                Spacer(minLength: spacerLength)
            }
        }
        .task {
            if text == nil {
                do {
                    self.text = try await chatObserver.decrypt(message)
                } catch {
                    print("Failed to decrypt message:", error)
                }
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
                text: Message.Sealed(
                    ephemeralPublicKeyData: Data(),
                    ciphertext: Data(),
                    signature: Data()
                ),
                chat: Chat.MessageResponse(id: UUID()),
                sender: Participant(
                    id: UUID(),
                    role: .participant,
                    user: AffirmateUser.ParticipantResponse(
                        id: UUID(),
                        username: "meowface"
                    ),
                    chat: Chat.ParticipantResponse(id: UUID()),
                    signingKey: Data(),
                    encryptionKey: Data()
                ),
                recipient: Participant(
                    id: UUID(),
                    role: .admin,
                    user: AffirmateUser.ParticipantResponse(
                        id: UUID(),
                        username: "barkface"
                    ),
                    chat: Chat.ParticipantResponse(id: UUID()),
                    signingKey: Data(),
                    encryptionKey: Data()
                )
            )
        )
    }
}
