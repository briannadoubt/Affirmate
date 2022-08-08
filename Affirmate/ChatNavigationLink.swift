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
}

final class ChatObserver: ObservableObject {
    @Published var chat: Chat
    @Published var messages: [Message] = []
    @Published var participants: [Participant] = []
    
    init(chat: Chat, messages: [Message] = [], participants: [Participant] = []) {
        self.chat = chat
        self.messages = messages
        self.participants = participants
    }
    
    func getChat() async throws {
        guard
            let chatId = chat.id?.uuidString,
            let chatUrl = Constants.baseURL?
                .appending(component: "chat")
                .appending(component: chatId)
        else {
            throw ChatError.failedToBuildURL
        }
        guard let token = KeychainWrapper.standard.string(forKey: Constants.tokenKey) else {
            throw ChatError.failedToRetrieveTokenFromKeychain
        }
        var request = URLRequest(url: chatUrl)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authentication")
        let (data, _) = try await URLSession.shared.data(for: request)
        let decoder = JSONDecoder()
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            throw ChatError.serverError(serverError)
        }
        let chatResponse = try decoder.decode(Chat.GetResponse.self, from: data)
        await setData(from: chatResponse)
    }
    
    @MainActor func setData(from chatResponse: Chat.GetResponse) {
        self.chat = chatResponse.chat
        self.messages = chatResponse.messages
        self.participants = chatResponse.participants
    }
}

struct ChatNavigationLink: View {
    
    @StateObject var chatObserver: ChatObserver
    let chat: Chat.GetResponse
    
    @State var lastMessageText: String?
    
    init(chat: Chat.GetResponse) {
        self.chat = chat
        let observer = ChatObserver(
            chat: chat.chat,
            messages: chat.messages,
            participants: chat.participants
        )
        _chatObserver = StateObject(wrappedValue: observer)
    }
    
    var body: some View {
        NavigationLink {
//            ChatView(chat: chat)
//                .environmentObject(chatObserver)
        } label: {
            VStack {
                if let lastMessage = chatObserver.messages.last {
                    Text(lastMessage.sender.username + ": ").bold()
                    Text(lastMessage.text)
                } else {
                    Text("No messages yet...")
                }
            }
        }
    }
}

struct ChatNavigationLink_Previews: PreviewProvider {
    static var previews: some View {
        ChatNavigationLink(
            chat: Chat.GetResponse(
                chat: Chat(name: "Demo"),
                participants: [
                    Participant(
                        role: .admin,
                        user: User(
                            firstName: "Meow",
                            lastName: "Face",
                            username: "Meow",
                            email: "meow@meow.com"
                        ),
                        chat: Chat(name: "Meowmeow")
                    )
                ],
                messages: [
                    Message(
                        text: "Meow!!!",
                        chat: Chat(name: "Meowmeow"),
                        sender: User(
                            firstName: "Meow",
                            lastName: "Face",
                            username: "Meow",
                            email: "meow@meow.com"
                        )
                    )
                ]
            )
        )
    }
}
