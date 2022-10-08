//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import Alamofire
import Foundation
import Starscream
import SwiftUI

class ChatObserver: WebSocketObserver {
    
    /// Whether or not the 
    @Published var isConnected = false
    let clientIdKey = Constants.chatClientIdKey
    var socket: WebSocket?
    
    @Published var name: String
    @Published var messages: [Message]
    @Published var participants: [Participant]
    var shareableUrl: URL {
        URL(string: "affirmate://chat?chatId:" + chatId.uuidString)!
    }
    
    private let chatActor = ChatsActor()
    private let chatId: UUID
    
    init(chat: Chat) {
        self.chatId = chat.id
        self.name = chat.name ?? "Chat"
        self.messages = chat.messages ?? []
        self.participants = chat.participants ?? []
        start(chat: chat)
    }
    
    func getChat(chatId: UUID) async throws {
        let chat = try await chatActor.get(chatId)
        await set(chat)
    }
    
    func sendMessage(_ text: String) throws {
        let newMessage = Message.Create(text: text)
        try write(newMessage)
    }
    
    func addParticipants(_ newParticipants: [Participant.Create]) throws {
        try write(newParticipants)
    }
    
    func recieved(_ data: Data) {
        if let newMessage = try? data.decodeWebSocketMessage(Message.self) {
            Task {
//                await self.set(clientId: newMessage.client)
                await self.insert(newMessage.data)
                print("WebSocket: Recieved message:", newMessage)
            }
        } else if let newParticipants = try? data.decodeWebSocketMessage([Participant].self) {
            Task {
//                await self.set(clientId: newParticipants.client)
                await self.add(newParticipants.data)
                print("WebSocket: Did add new participant:", newParticipants)
            }
        } else {
            print("WebSocket: Received unrecognized data:", (try? JSONSerialization.jsonObject(with: data) as Any) as? [String: Any] as Any)
        }
    }
}

private extension ChatObserver {
    
    func start(chat: Chat) {
        let sessionToken = chatActor.http.interceptor.sessionToken
        let request = ChatsActor.Request.chat(chatId: chat.id, sessionToken: sessionToken)
        guard let urlRequest = try? request.asURLRequest() else {
            assertionFailure()
            return
        }
        start(urlRequest)
        print(request)
    }
    
    @MainActor func insert(_ newMessage: Message) {
        withAnimation {
            self.messages.append(newMessage)
        }
    }
    
    @MainActor func add(_ participants: [Participant]) {
        withAnimation {
            self.participants.append(contentsOf: participants)
        }
    }
    
    @MainActor func set(_ chat: Chat) {
        withAnimation {
            self.messages = chat.messages ?? []
            self.participants = chat.participants ?? []
        }
    }
}
