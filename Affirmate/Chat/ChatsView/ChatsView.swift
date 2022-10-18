//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import SwiftUI

struct ChatsView: View {
    
    @StateObject var chatsObserver = ChatsObserver()
    
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    
    func getChats() async {
        do {
            try await chatsObserver.getChats()
        } catch {
            print("Failed to get chats:", error.localizedDescription)
        }
    }
    
    #if !os(watchOS) && !os(macOS)
    @State var navigationSplitViewVisibility: NavigationSplitViewVisibility = .all
    #endif
    
    @State var selectedChat: UUID?
    
    var body: some View {
        Group {
            #if os(watchOS)
            NavigationStack {
                ChatsList(getChats: getChats)
                    .environmentObject(authenticationObserver)
                    .environmentObject(chatsObserver)
            }
            #elseif os(macOS)
            NavigationView {
                ChatsList(selectedChat: $selectedChat, getChats: getChats)
                    .environmentObject(authenticationObserver)
                    .environmentObject(chatsObserver)
                
                if let selectedChat {
                    ChatView()
                        .environmentObject(ChatObserver(chat: selectedChat))
                } else {
                    Text("👈 Select a chat on the left")
                }
            }
            #else
            NavigationSplitView(columnVisibility: $navigationSplitViewVisibility) {
                ChatsList(selectedChat: $selectedChat, getChats: getChats)
                    .environmentObject(authenticationObserver)
                    .environmentObject(chatsObserver)
                    .navigationSplitViewColumnWidth(ideal: 320)
            } detail: {
                if
                    let selectedChat = selectedChat,
                    let chat = chatsObserver.chats.first(where: { $0.id == selectedChat }),
                    let currentUserId = authenticationObserver.currentUser?.id
                {
                    ChatView()
                        .environmentObject(ChatObserver(chat: chat, currentUserId: currentUserId))
                } else {
                    Text("👈 Select a chat on the left")
                }
            }
            .navigationSplitViewStyle(.automatic)
            #endif
        }
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
                    let chatId = UUID(uuidString: chatIdString)
                else {
                    return
                }
                selectedChat = chatId
            }
        }
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView()
    }
}
