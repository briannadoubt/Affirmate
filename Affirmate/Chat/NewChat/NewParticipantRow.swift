//
//  NewParticipantRow.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import AffirmateShared
import SwiftUI

struct NewParticipantRow: View {

    @Environment(NewParticipantsObserver.self) private var newParticipantObserver
    
    let publicUser: UserPublic
    
    @State var selectedRoleId: String = ParticipantRole.participant.rawValue
    
    var body: some View {
        Menu {
            Picker(selection: $selectedRoleId) {
                ForEach(ParticipantRole.allCases) { role in
                    Text(role.title)
                        .id(role.id)
                }
            } label: {
                Label("Role", systemImage: "key")
            }
            .pickerStyle(.menu)
            .onChange(of: selectedRoleId) { _, newRoleId in
                newParticipantObserver.set(
                    role: ParticipantRole(rawValue: newRoleId) ?? .participant,
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
                Text("@\(publicUser.username)")
                Spacer()
                Text(newParticipantObserver.selectedParticipants[publicUser.id]?.role.title ?? "")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NewParticipantRow_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantRow(
            publicUser: UserPublic(
                id: UUID(),
                username: "meowface"
            )
        )
    }
}
