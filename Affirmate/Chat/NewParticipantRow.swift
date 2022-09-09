//
//  NewParticipantRow.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct NewParticipantRow: View {
    
    @EnvironmentObject var newParticipantObserver: NewParticipantsObserver
    
    let publicUser: AffirmateUser.Public
    
    @State var selectedRoleId: String = Participant.Role.participant.rawValue
    
    var body: some View {
        Menu {
            Picker(selection: $selectedRoleId) {
                ForEach(Participant.Role.allCases) { role in
                    Text(role.description)
                        .id(role.id)
                }
            } label: {
                Label("Role", systemImage: "key")
            }
            .pickerStyle(.menu)
            .onChange(of: selectedRoleId) { newRoleId in
                newParticipantObserver.set(
                    role: Participant.Role(rawValue: newRoleId) ?? .participant,
                    for: publicUser
                )
            }
            
            Button {
                newParticipantObserver.remove(user: publicUser)
            } label: {
                Label("Remove", systemImage: "trash")
            }
        } label: {
            HStack {
                Text("@") + Text(publicUser.username)
                Spacer()
                Text(newParticipantObserver.selectedParticipants[publicUser]?.description ?? "")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewParticipantRow_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantRow(
            publicUser: AffirmateUser.Public(
                id: UUID(),
                username: "meowface"
            )
        )
    }
}
