//
//  NewParticipantsSelectionSection.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct NewParticipantsSelectionSection: View {
    
    @EnvironmentObject var newParticipantObserver: NewParticipantsObserver
    
    var body: some View {
        if !newParticipantObserver.selectedParticipants.isEmpty {
            Section {
                ForEach(newParticipantObserver.selectedParticipants.map { $1.user }, id: \.id) { user in
                    NewParticipantRow(publicUser: user)
                }
            } header: {
                Text("To be invited")
            } footer: {
                Text("Be sure to select a Role for each user you're adding!")
            }
        }
    }
}

struct NewParticipantsSelectionSection_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantsSelectionSection()
            .environmentObject(NewParticipantsObserver())
    }
}
