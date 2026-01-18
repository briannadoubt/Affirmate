//
//  ChatInvitationsView.swift
//  Affirmate
//
//  Created by Bri on 10/12/22.
//

import AffirmateShared
import SwiftUI

struct ChatInvitationsView: View {

    var invitations: [ChatInvitationResponse]

    @State private var chatInvitationObserver = ChatInvitationObserver()
    @Environment(AuthenticationObserver.self) private var authentication
    
    func joinChat(_ chatId: UUID, invitation: ChatInvitationResponse) {
        Task {
            do {
                let (signingPublicKey, _) = try await chatInvitationObserver.crypto.generateSigningKeyPair(for: chatId)
                let (encryptionPublicKey, _) = try await chatInvitationObserver.crypto.generateEncryptionKeyPair(for: chatId)
                let confirmation = ChatInvitationJoin(
                    id: invitation.id,
                    signingKey: signingPublicKey,
                    encryptionKey: encryptionPublicKey
                )
                try await chatInvitationObserver.joinChat(chatId, confirmation: confirmation)
                try await authentication.getCurrentUser()
            } catch {
                print("Failed to join chat:", error)
            }
        }
    }
    
    func declineInvitation(_ chatId: UUID, invitation: ChatInvitationResponse) {
        Task {
            do {
                let declination = ChatInvitationDecline(id: invitation.id)
                try await chatInvitationObserver.declineInvitation(chatId, declination: declination)
                try await authentication.getCurrentUser()
            } catch {
                print("Failed to decline invitation:", error)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(invitations) { invitation in
                let label = VStack {
                    let username = invitation.invitedByUsername
                    let chatContext = invitation.chatName == nil ? "chat" : "the chat"
                    let chatName = invitation.chatName == nil ? "" : " " + invitation.chatName!
                    let participantsCount = invitation.chatParticipantUsernames.count
                    let withOthersText = "** with \(participantsCount) others**"
                    let groupChatContextSuffix = participantsCount > 1 ? withOthersText : ""
                    Text("**\(username)** invited you to \(chatContext)**\(chatName)**\(groupChatContextSuffix)")
                }
                .foregroundColor(.primary)
                
                let joinButton = Button {
                    joinChat(invitation.chatId, invitation: invitation)
                } label: {
                    Label("Accept", systemImage: "checkmark")
                        .foregroundColor(Color.green)
                }
                
                let declineButton = Button {
                    declineInvitation(invitation.chatId, invitation: invitation)
                } label: {
                    Label("Decline", systemImage: "xmark")
                        .foregroundColor(.red)
                }
                
                #if os(watchOS)
                NavigationLink {
                    List {
                        Section {
                            label
                        }
                        Section {
                            joinButton
                            declineButton
                        }
                    }
                } label: {
                    label
                        .lineLimit(2)
                }
                #else
                Menu {
                    joinButton
                    declineButton
                } label: {
                    label
                }
                #endif
            }
        }
        .navigationTitle("Chat Invitations")
    }
}

struct ChatInvitationsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInvitationsView(invitations: [])
    }
}
