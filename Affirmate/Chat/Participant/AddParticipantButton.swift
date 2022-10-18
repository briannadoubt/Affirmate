//
//  AddParticipantButton.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct AddParticipantButton: View {
    
    @EnvironmentObject var newParticipantObserver: NewParticipantsObserver
    @EnvironmentObject var chatObserver: ChatObserver
    
    func addParticipants() {
        Task {
            do {
                let store = ChatsObserver.store
                guard let identity = AffirmateKeychain.chat[string: Constants.KeyChain.Chat.identity]?.data(using: .utf8) else {
                    assertionFailure("Failed to get identity.")
                    return
                }
                let newParticipants = try newParticipantObserver.selectedParticipants.map { user, role in
                    Participant.Create(
                        role: role,
                        user: user.id,
                        invitedBySignedPreKey: try store.updateSignedPrekey(),
                        invitedByIdentity: identity
                    )
                }
                try chatObserver.addParticipants(newParticipants)
            } catch {
                print("Failed to add participant:", error)
            }
        }
    }
    
    var body: some View {
        Button(action: addParticipants) {
            Label("Invite Users to \"\(chatObserver.name)\"", systemImage: "eyes")
        }
        .disabled(newParticipantObserver.selectedParticipants.isEmpty)
    }
}

struct AddParticipantButton_Previews: PreviewProvider {
    static var previews: some View {
        AddParticipantButton()
    }
}
