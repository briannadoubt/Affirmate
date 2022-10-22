//
//  ChatInvitationsView.swift
//  Affirmate
//
//  Created by Bri on 10/12/22.
//

import SwiftUI

struct ChatInvitationsView: View {
    
    var invitations: [ChatInvitation]
    
    @StateObject var chatInvitationObserver = ChatInvitationObserver()
    @EnvironmentObject var authentication: AuthenticationObserver
    
    func joinChat(_ chatId: UUID, invitation: ChatInvitation) {
        Task {
            do {
                let (signingPublicKey, _) = try await chatInvitationObserver.crypto.generateSigningKeyPair(for: chatId)
                let (encryptionPublicKey, _) = try await chatInvitationObserver.crypto.generateKeyAgreementKeyPair(for: chatId)
                let confirmation = ChatInvitation.Join(
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
    
    func declineInvitation(_ chatId: UUID, invitation: ChatInvitation) {
        Task {
            do {
                let declination = ChatInvitation.Decline(id: invitation.id)
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
                    Text("**\(invitation.invitedByUsername)** invited you to \(invitation.chatName == nil ? "chat" : "the chat")**\(invitation.chatName == nil ? "" : " " + invitation.chatName!)**")
                    + Text("**\(invitation.chatParticipantUsernames.count > 1 ? " with \(invitation.chatParticipantUsernames.count) others" : "")**")
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
