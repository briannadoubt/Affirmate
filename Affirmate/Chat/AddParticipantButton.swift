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
        let newParticipants = newParticipantObserver.selectedParticipants.map { user, role in
            Participant.Create(role: role, user: user.id)
        }
        Task {
            do {
                try chatObserver.addParticipants(newParticipants)
            } catch {
                print("TODO: Show error in UI:", error)
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
