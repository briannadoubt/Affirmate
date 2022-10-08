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
            print("TODO: Show this error in the UI:", error.localizedDescription)
        }
    }
    
#if !os(watchOS)
    @State var navigationSplitViewVisibility: NavigationSplitViewVisibility = .doubleColumn
#endif
    
    @State var selectedChat: Chat?
    
    var body: some View {
        Group {
#if os(watchOS)
            NavigationStack {
                ChatsList(getChats: getChats)
                    .environmentObject(authenticationObserver)
                    .environmentObject(chatsObserver)
            }
#else
            NavigationSplitView(columnVisibility: $navigationSplitViewVisibility) {
                ChatsList(selectedChat: $selectedChat, getChats: getChats)
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
