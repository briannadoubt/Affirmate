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

final class ChatObserver: ObservableObject {
    
    @Published var name: String
    @Published var messages: [Message]
    @Published var participants: [Participant]
    @Published var isConnected = false
    
    var shareableUrl: URL {
        URL(string: "affirmate://chat?chatId:" + chatId.uuidString)!
    }
    
    private var socket: WebSocket?
    private let chatActor = ChatsActor()
    private let chatId: UUID
    
    private var clientId: UUID {
        get {
            let uuidString = KeychainWrapper.standard.string(forKey: Constants.chatClientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)!
            return UUID(uuidString: uuidString)!
        }
    }
    
    init(chat: Chat) {
        self.chatId = chat.id
        self.name = chat.name ?? "Chat"
        self.messages = chat.messages ?? []
        self.participants = chat.participants ?? []
        setUpWebSocketConnection(chat: chat)
    }
    
    func connect() throws {
        if let socket {
            socket.connect()
            let connect = Connect(connect: true)
            try write(connect)
        }
    }
    
    func getChat(chatId: UUID) async throws {
        let chat = try await chatActor.get(chatId)
        await set(chat)
    }
    
    func sendMessage(_ text: String) throws {
        let newMessage = Message.Create(text: text)
        try write(newMessage, from: clientId)
    }
    
    func addParticipants(_ newParticipants: [Participant.Create]) throws {
        try write(newParticipants, from: clientId)
    }
}

private extension ChatObserver {
    
    func setUpWebSocketConnection(chat: Chat) {
        let sessionToken = chatActor.http.interceptor.sessionToken
        let request = ChatsActor.Request.chat(chatId: chat.id, sessionToken: sessionToken)
        guard let urlRequest = try? request.asURLRequest() else {
            assertionFailure()
            return
        }
        self.socket = WebSocket(request: urlRequest)
        self.socket?.delegate = self
        print(request)
    }
    
    func write<T: Codable>(_ data: T, from client: UUID = UUID()) throws {
        let webSocketMessage = WebSocketMessage<T>(client: client, data: data)
        socket?.write(data: try JSONEncoder().encode(webSocketMessage)) {
            print("Did write", T.self, "from client", client)
        }
    }
    
    @MainActor func set(isConnected: Bool) {
        set(clientId: isConnected ? UUID() : nil)
        withAnimation {
            self.isConnected = isConnected
        }
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
    
    func set(clientId: UUID?) {
        if let clientId {
            KeychainWrapper.standard.set(clientId.uuidString, forKey: Constants.chatClientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
        } else {
            KeychainWrapper.standard.removeObject(forKey: Constants.chatClientIdKey)
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
            if let connectionConfirmation = try? data.decodeWebSocketMessage(ConfirmConnection.self) {
                self.set(clientId: connectionConfirmation.client)
                print("WebSocket: Connection confirmed!")
            } else if let newMessage = try? data.decodeWebSocketMessage(Message.self) {
                self.set(clientId: newMessage.client)
                Task {
                    await self.insert(newMessage.data)
                    print("WebSocket: Recieved message:", newMessage)
                }
            } else if let newParticipants = try? data.decodeWebSocketMessage([Participant].self) {
                self.set(clientId: newParticipants.client)
                Task {
                    await self.add(newParticipants.data)
                    print("WebSocket: Did add new participant:", newParticipants)
                }
            } else if let webSocketError = try? JSONDecoder().decode(WebSocketError.self, from: data) {
                print("Recieved webSocket server error:", webSocketError)
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
