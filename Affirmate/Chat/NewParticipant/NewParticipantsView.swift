//
//  NewParticipantsView.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import SwiftUI

struct NewParticipantsView: View {
    
    @EnvironmentObject var chatObserver: ChatObserver
    @StateObject var newParticipantsObserver = NewParticipantsObserver()
    
    var newPublicUsers: [AffirmateUser.Public] {
        newParticipantsObserver.searchResults.filter { publicUser in
            !chatObserver.participants.contains { user in
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
        NewParticipantsView()
    }
}
