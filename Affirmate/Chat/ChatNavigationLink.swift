//
//  ChatNavigationLink.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI
import SwiftKeychainWrapper

enum ChatError: LocalizedError {
    case failedToBuildURL
    case failedToRetrieveTokenFromKeychain
    case serverError(ServerError)
    case chatIdNotFound
    case clientIdHasNotBeenSet
}

struct ChatNavigationLink: View {
    
    @StateObject var chatObserver: ChatObserver
    
    @State var lastMessageText: String?
    
    init(chat: Chat) {
        _chatObserver = StateObject(wrappedValue: ChatObserver(chat: chat))
    }
    
    var body: some View {
        
        NavigationLink {
            ChatView()
                .environmentObject(chatObserver)
        } label: {
            VStack {
                if let lastMessage = chatObserver.messages.last {
                    Text((lastMessage.sender.username) + ": ").bold()
                    Text(lastMessage.text)
                } else {
                    Text("No messages yet...")
                }
            }
        }
    }
}

//struct ChatNavigationLink_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatNavigationLink()
//        )
//    }
//}