//
//  NewParticipantsUsernameSearchFieldSection.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import AffirmateShared
import Observation
import SwiftUI

struct NewParticipantsUsernameSearchFieldSection: View {

    @Environment(NewParticipantsObserver.self) private var newParticipantsObserver
    
    var newPublicUsers: [UserPublic]
    
    @MainActor func didSelect(publicUser: UserPublic) {
        withAnimation {
            newParticipantsObserver.select(user: publicUser)
            newParticipantsObserver.set(searchResults: [])
            newParticipantsObserver.username = ""
        }
    }
    
    var body: some View {
        @Bindable var participantsObserver = newParticipantsObserver
        Section {
            TextField("Username", text: $participantsObserver.username)
                #if !os(macOS)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                #endif
                #if !os(watchOS) && !os(macOS)
                .keyboardType(.twitter)
                #endif
                .onChange(of: participantsObserver.username) { _, newUsername in
                    guard !newUsername.isEmpty else { return }
                    Task { [newUsername] in
                        try await Task.sleep(for: .seconds(1))
                        let currentUsername = newParticipantsObserver.username
                        guard newUsername == currentUsername else { return }
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

// TODO: Fix previews
//struct NewParticipantsUsernameSearchFieldSection_Previews: PreviewProvider {
//    static let chat = Chat.GetResponse(
//        id: UUID(),
//        name: "Meow",
//        salt: Data(),
//        messages: [
//            Message.GetResponse(
//                id: UUID(),
//                text: Message.Sealed(
//                    ephemeralPublicKeyData: Data(),
//                    ciphertext: Data(),
//                    signature: Data()
//                ),
//                chat: Chat.MessageResponse(id: UUID(), name: "Meow"),
//                sender: Participant.GetResponse(
//                    id: UUID(),
//                    role: .admin,
//                    user: User.ParticipantResponse(
//                        id: UUID(),
//                        username: "meowface"
//                    ),
//                    chat: Chat.ParticipantResponse(id: UUID()),
//                    signingKey: Data(),
//                    encryptionKey: Data()
//                ),
//                recipient: Participant.GetResponse(
//                    id: UUID(),
//                    role: .participant,
//                    user: User.ParticipantResponse(
//                        id: UUID(),
//                        username: "barkface"
//                    ),
//                    chat: Chat.ParticipantResponse(id: UUID()),
//                    signingKey: Data(),
//                    encryptionKey: Data()
//                )
//            )
//        ],
//        participants: [
//            Participant.GetResponse(
//                id: UUID(),
//                role: .admin,
//                user: User.ParticipantResponse(id: UUID(), username: "meowface"),
//                chat: Chat.ParticipantResponse(id: UUID()),
//                signingKey: Data(),
//                encryptionKey: Data()
//            )
//        ]
//    )
//
//    static var previews: some View {
//        NewParticipantsUsernameSearchFieldSection(
//            newPublicUsers: [
//                User.Public(
//                    id: UUID(),
//                    username: "meowface"
//                )
//            ]
//        )
//        .environmentObject(ChatObserver(chat: chat, currentUserId: UUID()))
//        .environmentObject(NewParticipantsObserver())
//    }
//}
