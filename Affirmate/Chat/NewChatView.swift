//
//  NewChatView.swift
//  Affirmate
//
//  Created by Bri on 8/8/22.
//

import SwiftUI

struct NewChatButton: View {
    
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
    
    @SceneStorage("newChat.name") var name: String = ""
    
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
                try await chatsObserver.newChat(Chat.Create(name: name, participants: newParticipantsCreate))
                try await chatsObserver.getChats()
                dismiss()
            } catch {
                print("TODO: Show this error in the UI:", error.localizedDescription)
            }
        }
    }
    
    var newParticipantsCreate: [Participant.Create] {
        newParticipantsObserver.selectedParticipants.map {
            Participant.Create(role: $0.value, user: $0.key.id)
        }
    }
    
    var newPublicUsers: [AffirmateUser.Public] {
        newParticipantsObserver.searchResults.filter { publicUser in
            authenticationObserver.currentUser?.id != publicUser.id
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Name", text: $name)
                } footer: {
                    Text("Choose a name for your new chat!")
                }
                NewParticipantsUsernameSearchFieldSection(newPublicUsers: newPublicUsers)
                NewParticipantsSelectionSection()
                Section {
                    NewChatButton(newChat: newChat)
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
