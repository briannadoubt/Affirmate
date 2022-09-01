//
//  NewParticipantsView.swift
//  Affirmate
//
//  Created by Bri on 8/26/22.
//

import SwiftUI
import Combine

struct PublicUserRow: View {
    let publicUser: User.Public
    var body: some View {
        HStack {
            Text("@") + Text(publicUser.username)
        }
    }
}

struct NewParticipantRow: View {
    let publicUser: User.Public
    @Binding var roleId: String
    var body: some View {
        VStack(alignment: .leading) {
            Text("@") + Text(publicUser.username)
            Picker(selection: $roleId) {
                ForEach(Participant.Role.allCases) { role in
                    Text(role.description)
                        .id(role.id)
                }
            } label: {
                Label("Role", systemImage: "key")
            }
            .pickerStyle(.menu)
        }
    }
}

struct NewParticipantsView: View {
    
    @EnvironmentObject var chatObserver: ChatObserver
    @StateObject var newParticipantObserver = NewParticipantObserver()
    
    @MainActor func didSelect(publicUser: User.Public) {
        withAnimation {
            self.newParticipantObserver.selectedParticipants[publicUser] = .participant
        }
    }
    
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
    
    var newPublicUsers: [User.Public] {
        newParticipantObserver.searchResults.filter({ publicUser in
            !chatObserver.participants.contains { user in
                publicUser.id == user.id
            }
        })
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Username", text: $newParticipantObserver.username)
                        .onReceive(newParticipantObserver.$username.debounce(for: 1, scheduler: RunLoop.main)) { newUserName in
                            guard !newUserName.isEmpty else {
                                return
                            }
                            Task {
                                do {
                                    try await newParticipantObserver.find()
                                } catch {
                                    print("TODO: Show this error on the UI:", error)
                                }
                            }
                        }
                    ForEach(newPublicUsers) { publicUser in
                        HStack {
                            Button {
                                withAnimation {
                                    newParticipantObserver.selectedParticipants[publicUser] = .participant
                                }
                            } label: {
                                PublicUserRow(publicUser: publicUser)
                            }
                        }
                    }
                } header: {
                    Text("Search")
                } footer: {
                    if newParticipantObserver.searchResults.isEmpty {
                        Text("Start typing someone's username to search for their profile.")
                    }
                }
                if !newParticipantObserver.selectedParticipants.isEmpty {
                    Section {
                        ForEach(Array(newParticipantObserver.selectedParticipants.keys), id: \.id) { user in
                            NewParticipantRow(
                                publicUser: user,
                                roleId: Binding<String>(
                                    get: {
                                        newParticipantObserver.selectedParticipants[user]?.id ?? ""
                                    },
                                    set: { newRoleId, transaction in
                                        newParticipantObserver.selectedParticipants[user] = Participant.Role(rawValue: newRoleId) ?? .participant
                                    }
                                )
                                .animation()
                            )
                        }
                    } header: {
                        Text("To be invited")
                    } footer: {
                        Text("Be sure to select a Role for each user you're adding!")
                    }
                }
                Section {
                    Button(action: addParticipants) {
                        Label("Invite Users to \"\(chatObserver.name)\"", systemImage: "eyes")
                    }
                    .disabled(newParticipantObserver.selectedParticipants.isEmpty)
                }
            }
            .navigationTitle("New Participant")
        }
    }
}

struct NewParticipantsView_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantsView()
    }
}
