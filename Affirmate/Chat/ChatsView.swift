//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import SwiftUI

struct ChatsListView: View {
    @Binding var selectedChat: Chat?
    @EnvironmentObject var chatsObserver: ChatsObserver
    @EnvironmentObject var authentication: Authentication
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    var getChats: () async -> ()
    var body: some View {
        List(selection: $selectedChat) {
            ForEach(chatsObserver.chats) { chat in
                VStack {
                    if let lastMessage = chat.messages?.last {
                        Text((lastMessage.sender.username) + ": ").bold()
                        Text(lastMessage.text)
                    } else {
                        Text("No messages yet...")
                    }
                }
                .tag(chat)
            }
        }
        .refreshable {
            await getChats()
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

struct ChatsView: View {
    
    @StateObject var chatsObserver = ChatsObserver()
    @EnvironmentObject var authentication: Authentication
    
    func getChats() async {
        do {
            try await chatsObserver.getChats()
        } catch {
            print("TODO: Show this error in the UI:", error.localizedDescription)
        }
    }
    
    @State var navigationSplitViewVisibility: NavigationSplitViewVisibility = .doubleColumn
    
    @State var selectedChat: Chat?
    
    var body: some View {
        NavigationSplitView(
            columnVisibility: $navigationSplitViewVisibility
        ) {
            ChatsListView(selectedChat: $selectedChat, getChats: getChats)
                .environmentObject(authentication)
                .environmentObject(chatsObserver)
                .navigationSplitViewColumnWidth(ideal: 320)
        } detail: {
            if let selectedChat {
                ChatView()
                    .environmentObject(ChatObserver(chat: selectedChat))
            } else {
                Text("👈 Select a chat on the left")
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView()
    }
}
