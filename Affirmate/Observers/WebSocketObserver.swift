//
//  WebSocketObserver.swift
//  Affirmate
//
//  Created by Bri on 9/9/22.
//

import Foundation
import Starscream
import SwiftKeychainWrapper
import SwiftUI

protocol WebSocketObserver: ObservableObject, WebSocketDelegate {
    var isConnected: Bool { get set }
    var socket: WebSocket? { get set }
    var clientIdKey: String { get }
    var clientId: UUID? { get }
    func connect() throws
    func start(_ urlRequest: URLRequest)
    func set(isConnected: Bool)
    func recieved(_ data: Data)
    func recieved(_ text: String)
}

extension WebSocketObserver {
    
    var clientId: UUID? {
        get {
            let uuidString = KeychainWrapper.standard.string(forKey: clientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
            return UUID(uuidString: uuidString ?? "")
        }
        set {
            if let newValue {
                KeychainWrapper.standard.set(newValue.uuidString, forKey: clientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
            } else {
                KeychainWrapper.standard.removeObject(forKey: clientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
            }
        }
    }
    
    func start(_ urlRequest: URLRequest) {
        socket = WebSocket(request: urlRequest)
        socket?.delegate = self
    }
    
    func disconnect() {
        socket?.disconnect()
        socket = nil
    }
    
    func write<T: Codable>(_ data: T) throws {
        guard let clientId else {
            clientId = nil
            clientId = UUID()
            try write(data)
            return
        }
        let webSocketMessage = WebSocketMessage<T>(client: clientId, data: data)
        socket?.write(data: try JSONEncoder().encode(webSocketMessage)) {
            print("Did write", T.self, "from client with ID", clientId)
        }
    }
    
    func connect() throws {
        if let socket {
            socket.connect()
            let connect = Connect(connect: true)
            try write(connect)
        }
    }
    
    @MainActor func set(isConnected: Bool) {
        Task {
            clientId = nil
            if isConnected {
                clientId = UUID()
            }
            self.isConnected = isConnected
        }
    }
    
//    @MainActor func set(clientId: UUID?) {
//        if let clientId {
//            KeychainWrapper.standard.set(clientId.uuidString, forKey: Constants.chatClientIdKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
//        } else {
//            KeychainWrapper.standard.removeObject(forKey: Constants.chatClientIdKey)
//        }
//    }
    
    func recieved(_ text: String) { }
    
    func recieved(_ data: Data) { }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocket) {
        switch event {
        case .connected(let headers):
            Task {
                self.set(isConnected: true)
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
                self.set(isConnected: false)
            }
            print("WebSocket: Did disconnect: \(reason) with code: \(code)")
        case .text(let text):
            print("WebSocket: Recieved text:", text)
            recieved(text)
        case .binary(let data):
            if let connectionConfirmation = try? data.decodeWebSocketMessage(ConfirmConnection.self) {
                clientId = nil
                clientId = connectionConfirmation.client
                print("WebSocket: Connection confirmed!")
            } else if let webSocketError = try? JSONDecoder().decode(WebSocketError.self, from: data) {
                print("Recieved webSocket server error:", webSocketError)
            } else {
                print("WebSocket: Recieved data")
                recieved(data)
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
                self.set(isConnected: false)
            }
            print("WebSocket: Connection was cancelled")
        case .error(let error):
            Task {
                self.set(isConnected: false)
            }
            print("WebSocket: TODO: Show this error on the UI:", error as Any)
        }
    }
}
