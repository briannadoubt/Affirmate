//
//  NewParticipantsView.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import AffirmateShared
import SwiftUI

struct NewParticipantsView: View {
    
    @EnvironmentObject var chatObserver: ChatObserver
    @StateObject var newParticipantsObserver = NewParticipantsObserver()
    
    var participants: Set<Participant>
    
    var newPublicUsers: [UserPublic] {
        newParticipantsObserver.searchResults.filter { publicUser in
            !participants.contains { user in
                publicUser.id == user.id
            }
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                NewParticipantsUsernameSearchFieldSection(newPublicUsers: newPublicUsers)
                NewParticipantsSelectionSection()
                Section {
                    AddParticipantButton()
                }
            }
            .navigationTitle("New Participant")
        }
        .environmentObject(newParticipantsObserver)
    }
}

struct NewParticipantsView_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantsView(participants: [])
    }
}
