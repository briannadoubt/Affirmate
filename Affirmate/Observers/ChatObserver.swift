//
//  ChatObserver.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import Alamofire
import Foundation
import Starscream
import SwiftKeychainWrapper
import SwiftUI

struct WebSocketMessage<T: Codable>: Codable {
    let client: UUID
    let data: T
}

extension Data {
    func decodeWebSocketMessage<T: Codable>(_: T.Type) throws -> WebSocketMessage<T> {
        return try JSONDecoder().decode(WebSocketMessage<T>.self, from: self)
    }
}

final class ChatObserver: ObservableObject {
    
    var chatId: UUID
    
    var clientId: UUID {
        get {
            let uuidString = KeychainWrapper.standard.string(forKey: Constants.chatClientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)!
            return UUID(uuidString: uuidString)!
        }
    }
    
    @Published var name: String
    @Published var messages: [Message]
    @Published var participants: [Participant]
    @Published var isConnected = false
    
    private var socket: WebSocket?
    
    let actor = ChatsActor()
    
    init(chat: Chat) {
        self.chatId = chat.id
        self.name = chat.name ?? "Chat"
        self.messages = chat.messages ?? []
        self.participants = chat.participants ?? []
        setUpWebSocketConnection(chat: chat)
    }
    
    @MainActor func set(isConnected: Bool) {
        set(clientId: isConnected ? UUID() : nil)
        withAnimation {
            self.isConnected = isConnected
        }
    }
    
    func set(clientId: UUID?) {
        if let clientId {
            KeychainWrapper.standard.set(clientId.uuidString, forKey: Constants.chatClientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
        } else {
            KeychainWrapper.standard.removeObject(forKey: Constants.chatClientIdKey)
        }
    }
    
    @MainActor func insert(_ newMessage: Message) {
        withAnimation {
            self.messages.append(newMessage)
        }
    }
    
    func setUpWebSocketConnection(chat: Chat) {
        let sessionToken = actor.http.interceptor.sessionToken
        let request = ChatsActor.Request.chat(chatId: chat.id, sessionToken: sessionToken)
        guard let urlRequest = try? request.asURLRequest() else {
            assertionFailure()
            return
        }
        self.socket = WebSocket(request: urlRequest)
        self.socket?.delegate = self
        print(request)
    }
    
    func connect() throws {
        if let socket {
            socket.connect()
            let connect = Connect(connect: true)
            try write(connect)
        }
    }
    
    func getChat(chatId: UUID) async throws {
        let chat = try await actor.get(chatId)
        await setMessages(from: chat)
    }
    
    func sendMessage(_ text: String) throws {
        let newMessage = Message.Create(text: text)
        try write(newMessage, from: clientId)
    }
    
    func addParticipant(_ user: User, role: Participant.Role) throws {
        let newParticipant = Participant.Create(role: role, user: user.id, chat: chatId)
        try write(newParticipant, from: clientId)
    }
    
    func write<T: Codable>(_ data: T, from client: UUID = UUID()) throws {
        let webSocketMessage = WebSocketMessage<T>(client: client, data: data)
        socket?.write(data: try JSONEncoder().encode(webSocketMessage)) {
            print("Did write", T.self, "from client", client)
        }
    }
    
    @MainActor func setMessages(from chat: Chat) {
        withAnimation {
            self.messages = chat.messages ?? []
        }
    }
}

extension ChatObserver: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
        switch event {
        case .connected(let headers):
            Task {
                await self.set(isConnected: true)
            }
            print("WebSocket: did connect: \(headers)")
            let connect = Connect(connect: true)
            do {
                try write(connect)
            } catch {
                print("Connection message failed to send")
            }
        case .disconnected(let reason, let code):
            Task {
                await self.set(isConnected: false)
            }
            print("WebSocket: Did disconnect: \(reason) with code: \(code)")
        case .text(let text):
            print("WebSocket: Recieved text:", text)
        case .binary(let data):
            if let newMessage = try? data.decodeWebSocketMessage(Message.self) {
                self.set(clientId: newMessage.client)
                Task {
                    await self.insert(newMessage.data)
                    print("WebSocket: Recieved message:", newMessage)
                }
            } else if let connectionConfirmation = try? data.decodeWebSocketMessage(ConfirmConnection.self) {
                self.set(clientId: connectionConfirmation.client)
                print("WebSocket: Connection confirmed!")
            } else if let serverError = try? JSONDecoder().decode(WebSocketError.self, from: data) {
                print("Recieved server error:", serverError)
            } else {
                print("WebSocket: Received unrecognized data:", (try? JSONSerialization.jsonObject(with: data) as Any) as? [String: Any] as Any)
            }
        case .ping(let data):
            print("WebSocket: Recieved Ping:", data as Any)
        case .pong(let data):
            print("WebSocket: Recieved Pong:", data as Any)
        case .viabilityChanged(let changed):
            print("WebSocket: Visibility changed:", changed)
        case .reconnectSuggested(let reconnectSuggested):
            print("WebSocket: Reconnect suggested:", reconnectSuggested)
            if reconnectSuggested {
                client.connect()
            }
        case .cancelled:
            Task {
                await self.set(isConnected: false)
            }
            print("WebSocket: Connection was cancelled")
        case .error(let error):
            Task {
                await self.set(isConnected: false)
            }
            print("WebSocket: TODO: Show this error on the UI:", error as Any)
        }
    }
}
