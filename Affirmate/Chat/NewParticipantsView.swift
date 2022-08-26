//
//  NewParticipantsView.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import SwiftUI

struct NewParticipantsView: View {
    @EnvironmentObject var chatObserver: ChatObserver
    @SceneStorage("newParticipant_username") var username: String = ""
    var body: some View {
        NavigationView {
            Form {
                TextField("Username", text: $username)
            }
            .navigationTitle("Add Participant(s) to " + chatObserver.name)
        }
    }
}

struct NewParticipantsView_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantsView()
    }
}
