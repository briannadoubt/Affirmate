//
//  NewParticipantsUsernameSearchFieldSection.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct NewParticipantsUsernameSearchFieldSection: View {
    
    @EnvironmentObject var newParticipantsObserver: NewParticipantsObserver
    
    var newPublicUsers: [AffirmateUser.Public]
    
    @MainActor func didSelect(publicUser: AffirmateUser.Public) {
        withAnimation {
            newParticipantsObserver.select(user: publicUser)
            newParticipantsObserver.set(searchResults: [])
            newParticipantsObserver.username = ""
        }
    }
    
    var body: some View {
        Section {
            TextField("Username", text: $newParticipantsObserver.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.twitter)
                .onReceive(newParticipantsObserver.$username.debounce(for: 1, scheduler: RunLoop.main)) { newUserName in
                    guard !newUserName.isEmpty else {
                        return
                    }
                    Task {
                        do {
                            try await newParticipantsObserver.find()
                        } catch {
                            print("TODO: Show this error on the UI:", error)
                        }
                    }
                }
            ForEach(newPublicUsers) { publicUser in
                HStack {
                    Button {
                        Task {
                            didSelect(publicUser: publicUser)
                        }
                    } label: {
                        PublicUserRow(publicUser: publicUser)
                    }
                }
            }
        } header: {
            Text("Search For Uername")
        } footer: {
            if newParticipantsObserver.searchResults.isEmpty {
                Text("Start typing someone's username to search for their profile.")
            }
        }
    }
}

struct NewParticipantsUsernameSearchFieldSection_Previews: PreviewProvider {
    static let chat = Chat(
        id: UUID(),
        name: "Meow",
        messages: [
            Message(
                id: UUID(),
                text: "Meow meow meow",
                chat: Chat.MessageResponse(
                    id: UUID(),
                    name: "Meow"
                ),
                sender: Participant.GetResponse(
                    id: UUID(),
                    role: .admin,
                    user: AffirmateUser.Public(
                        id: UUID(),
                        username: "meowface"
                    ),
                    chat: Chat.ParticipantResponse(id: UUID())
                )
            )
        ],
        participants: [
            Participant(
                id: UUID(),
                role: .admin,
                user: AffirmateUser.Public(
                    id: UUID(),
                    username: "meowface"
                ),
                chat: Relation(id: UUID())
            )
        ]
    )
    static var previews: some View {
        NewParticipantsUsernameSearchFieldSection(
            newPublicUsers: [
                AffirmateUser.Public(
                    id: UUID(),
                    username: "meowface"
                )
            ]
        )
        .environmentObject(ChatObserver(chat: chat))
        .environmentObject(NewParticipantsObserver())
    }
}
