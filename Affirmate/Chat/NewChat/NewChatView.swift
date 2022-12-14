//
//  NewChatView.swift
//  Affirmate
//
//  Created by Bri on 8/8/22.
//

import AffirmateShared
import SwiftUI

struct CreateNewChatButton: View {
    
    @EnvironmentObject var newParticipantsObserver: NewParticipantsObserver
    
    var newChat: () -> ()
    
    var body: some View {
        Button(action: newChat) {
            Label("New Chat", systemImage: "plus")
        }
        .disabled(newParticipantsObserver.selectedParticipants.isEmpty)
    }
}

struct NewChatView: View {
    
    @Binding var isPresented: Bool
    
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    @EnvironmentObject var chatsObserver: ChatsObserver
    
    @StateObject var newParticipantsObserver = NewParticipantsObserver()
    
    @State var name: String = ""
    
    @MainActor func dismiss() {
        withAnimation {
            isPresented = false
        }
    }
    
    func newChat() {
        Task {
            do {
                guard !newParticipantsObserver.selectedParticipants.isEmpty else {
                    throw ChatError.chatWithNoOtherParticipants
                }
                try await chatsObserver.newChat(
                    name: name == "" ? nil : name,
                    selectedParticipants: newParticipantsObserver.selectedParticipants
                )
                try await chatsObserver.getChats()
                dismiss()
            } catch {
                print("Failed to create new chat:", error)
            }
        }
    }
    
    var newDraftParticipants: [ParticipantDraft] {
        return newParticipantsObserver.selectedParticipants.map { index in
            let role = index.value.role
            let publicUser = index.value.user
            return ParticipantDraft(
                role: role,
                user: publicUser.id
            )
        }
    }
    
    var newPublicUsers: [UserPublic] {
        newParticipantsObserver.searchResults.filter { publicUser in
            authenticationObserver.currentUser?.id != publicUser.id
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Name (Optional)", text: $name)
                } footer: {
                    Text("Choose a name for your new chat!")
                }
                NewParticipantsUsernameSearchFieldSection(newPublicUsers: newPublicUsers)
                NewParticipantsSelectionSection()
                Section {
                    CreateNewChatButton(newChat: newChat)
                }
            }
            .navigationTitle("New Chat")
        }
        .environmentObject(newParticipantsObserver)
    }
}

struct NewChatView_Previews: PreviewProvider {
    static var previews: some View {
        NewChatView(isPresented: .constant(true))
    }
}
