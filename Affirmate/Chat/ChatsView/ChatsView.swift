//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import CoreData
import SwiftUI

struct ChatsView: View {

    @FetchRequest(sortDescriptors: []) var chats: FetchedResults<Chat>

    @State private var chatsObserver: ChatsObserver

    @Environment(AuthenticationObserver.self) private var authenticationObserver
    
    let currentUserId: UUID
    
    init(currentUserId: UUID, managedObjectContext: NSManagedObjectContext) {
        self.currentUserId = currentUserId
        _chatsObserver = State(
            initialValue: ChatsObserver(
                currentUserId: currentUserId,
                managedObjectContext: managedObjectContext
            )
        )
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
    
    @State var selectedChat: Chat?
    
    var body: some View {
        Group {
            let chat = Group {
                    if
                        let selectedChat,
                        let selectedChatId = selectedChat.id,
                        let chatObserver = chatsObserver.chatObservers[selectedChatId]
                    {
                        ChatView(chatId: selectedChatId)
                            .environment(chatObserver)
                    } else {
                        Text("👈 Select a chat on the left")
                    }
                }
            #if os(watchOS)
            NavigationStack {
                ChatsList(chats: Array(chats), getChats: getChats)
                    .environment(authenticationObserver)
                    .environment(chatsObserver)
            }
            #elseif os(macOS)
            NavigationView {
                ChatsList(chats: Array(chats), selectedChat: $selectedChat, getChats: getChats)
                    .environment(authenticationObserver)
                    .environment(chatsObserver)
                chat
            }
            #else
            NavigationSplitView(columnVisibility: $navigationSplitViewVisibility) {
                ChatsList(chats: Array(chats), selectedChat: $selectedChat, getChats: getChats)
                    .environment(authenticationObserver)
                    .environment(chatsObserver)
                    .navigationSplitViewColumnWidth(ideal: 320)
            } detail: {
                chat
            }
            .navigationSplitViewStyle(.automatic)
            #endif
        }
    }
}

// TODO: Fix Preview
//struct ChatsView_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatsView(currentUserId: UUID(), managedObjectContext: <#NSManagedObjectContext#>)
//    }
//}
