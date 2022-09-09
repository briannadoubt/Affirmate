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
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    @SceneStorage("chat.isShowingNewChat") var isShowingNewChat = false
    var getChats: () async -> ()
    var body: some View {
        List(selection: $selectedChat) {
            ForEach(chatsObserver.chats) { chat in
                VStack {
                    if let lastMessage = chat.messages?.last {
                        Text((lastMessage.sender.user.username) + ": ").bold()
                        Text(lastMessage.text ?? "")
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
                    NewChatView(isPresented: $isShowingNewChat)
                        .environmentObject(chatsObserver)
                        .environmentObject(authenticationObserver)
                }
            }
        }
    }
}

struct ChatsView: View {
    
    @StateObject var chatsObserver = ChatsObserver()
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    
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
        NavigationSplitView(columnVisibility: $navigationSplitViewVisibility) {
            ChatsListView(selectedChat: $selectedChat, getChats: getChats)
                .environmentObject(authenticationObserver)
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
        .onOpenURL { url in
            guard
                let firstPathComponent = url.pathComponents.first,
                let deepLink = DeepLink(rawValue: firstPathComponent)
            else {
                return
            }
            switch deepLink {
            case .chat:
                guard
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                    let queryItems = components.queryItems,
                    let chatIdQueryItem = queryItems.first(where: { $0.name == "chatId"}),
                    let chatIdString = chatIdQueryItem.value,
                    let chatId = UUID(uuidString: chatIdString),
                    let chat = chatsObserver.chats.first(where: { $0.id == chatId })
                else {
                    return
                }
                selectedChat = chat
            }
        }
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView()
    }
}
