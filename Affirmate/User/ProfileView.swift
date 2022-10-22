//
//  ProfileView.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var chatObserver: ChatObserver

    let user: AffirmateUser.ParticipantResponse
    
    init(user: AffirmateUser.ParticipantResponse) {
        self.user = user
    }
    
    init(participant: Participant.GetResponse) {
        self.user = participant.user
    }

    var body: some View {
        List {
            Section {
//                HStack {
//                    Text("Name:").bold()
//                    Text(user.firstName + " " + user.lastName)
//                }
                HStack {
                    Text("Username").bold()
                    Text(user.username)
                }
//                HStack {
//                    Text("Email").bold()
//                    Text(user.email)
//                }
            } header: {
                Text("Info")
            }
//            Section {
//                Button {
//                    do {
//                        try chatObserver.addParticipants(<#T##newParticipants: [Participant.Create]##[Participant.Create]#>)
//                        try chatObserver.addParticipant(user, role: .participant)
//                    } catch {
//                    }
//                } label: {
//                    Label("Add to Chat", systemImage: "plus.message")
//                }
//            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView(user: AffirmateUser.ParticipantResponse(id: UUID(), username: "meowface"))
    }
}
