//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import SwiftUI

struct ChatsView: View {
    
    @FetchRequest(sortDescriptors: []) var fetchedChats: FetchedResults<Chat>
    
    var chats: [Chat] { Array(fetchedChats) }
    
    @StateObject var chatsObserver: ChatsObserver
    
    @EnvironmentObject var authenticationObserver: AuthenticationObserver
    
    let currentUserId: UUID
    
    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
        _chatsObserver = StateObject(wrappedValue: ChatsObserver(currentUserId: currentUserId))
    }
    
    func getChats() async {
        do {
            try await chatsObserver.getChats()
        } catch {
            print("Failed to get chats:", error)
        }
    }
    
    #if !os(watchOS) && !os(macOS)
    @State var navigationSplitViewVisibility: NavigationSplitViewVisibility = .all
    #endif
    
    @State var selectedChat: UUID?
    
    var body: some View {
        Group {
            let chat = Group {
                if let selectedChat, let chatObserver = chatsObserver.chatObservers[selectedChat] {
                    ChatView()
                        .environmentObject(chatObserver)
                } else {
                    Text("👈 Select a chat on the left")
                }
            }
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
                chat
            }
            #else
            NavigationSplitView(columnVisibility: $navigationSplitViewVisibility) {
                ChatsList(chats: chats, selectedChat: $selectedChat, getChats: getChats)
                    .environmentObject(authenticationObserver)
                    .environmentObject(chatsObserver)
                    .navigationSplitViewColumnWidth(ideal: 320)
            } detail: {
                chat
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
        ChatsView(currentUserId: UUID())
    }
}
