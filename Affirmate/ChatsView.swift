//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import SwiftUI

struct ChatsView: View {
    
    @StateObject var chatsObserver = ChatsObserver()
    
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    
    func getChats() async {
        do {
            try await chatsObserver.getChats()
        } catch {
            print("TODO: Show this error in the UI:", error.localizedDescription)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chatsObserver.chats) { chat in
                    ChatNavigationLink(chat: chat)
                }
            }
            .task {
                await getChats()
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingNewChat.toggle() }) {
                        Label("New Chat", systemImage: "plus")
                    }
                    .popover(isPresented: $isShowingNewChat) {
                        NewChatView()
                            .environmentObject(chatsObserver)
                    }
                }
            }
        }
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView()
    }
}
