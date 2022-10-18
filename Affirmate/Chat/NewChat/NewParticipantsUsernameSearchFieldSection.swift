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
                #if !os(macOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                #if !os(watchOS) && !os(macOS)
                .keyboardType(.twitter)
                #endif
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
                        NewParticipantPublicUserRow(publicUser: publicUser)
                    }
                }
            }
        } header: {
            Text("Search For Username")
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
                text: "Meow meow meow".data(using: .utf8),
                chat: Chat.MessageResponse(id: UUID(), name: "Meow"),
                sender: Participant(
                    id: UUID(),
                    role: .admin,
                    user: AffirmateUser.ParticipantResponse(id: UUID(), username: "meowface"),
                    chat: Chat.ParticipantResponse(id: UUID()),
                    signedPreKey: Data()
                )
            )
        ],
        participants: [
            Participant(
                id: UUID(),
                role: .admin,
                user: AffirmateUser.ParticipantResponse(id: UUID(), username: "meowface"),
                chat: Chat.ParticipantResponse(id: UUID()),
                signedPreKey: Data()
            )
        ],
        preKey: Data()
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
        .environmentObject(ChatObserver(chat: chat, currentUserId: UUID()))
        .environmentObject(NewParticipantsObserver())
    }
}
