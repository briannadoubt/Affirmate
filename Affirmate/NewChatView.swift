//
//  NewChatView.swift
//  Affirmate
//
//  Created by Bri on 8/8/22.
//

import SwiftUI

struct NewChatView: View {
    
    @EnvironmentObject var chatObserver: ChatsObserver
    
    @SceneStorage("newChat.name") var name: String = ""
    
    func newChat() {
        Task {
            do {
                try await chatObserver.newChat(Chat.Create(name: name))
                try await chatObserver.getChats()
            } catch {
                print("TODO: Show this error in the UI:", error.localizedDescription)
            }
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
                Section {
                    Button(action: newChat) {
                        Label("New Chat", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Chat")
        }
    }
}

struct NewChatView_Previews: PreviewProvider {
    static var previews: some View {
        NewChatView()
    }
}
