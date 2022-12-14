//
//  AddParticipantButton.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import AffirmateShared
import SwiftUI

struct AddParticipantButton: View {
    
    @EnvironmentObject var newParticipantObserver: NewParticipantsObserver
    
    @EnvironmentObject var chatObserver: ChatObserver
    
    func addParticipants() {
        Task {
            do {
                let newParticipants = newParticipantObserver.selectedParticipants.map { id, value in
                    ParticipantCreate(
                        role: value.role,
                        user: value.user.id
                    )
                }
                try chatObserver.inviteParticipants(newParticipants)
            } catch {
                print("Failed to invite participants:", error)
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
