//
//  WebSocketObserver.swift
//  Affirmate
//
//  Created by Bri on 9/9/22.
//

import AffirmateShared
import Foundation
import Starscream
import SwiftUI

/// An object that manages a WebSocket connection to a server for a View.
protocol WebSocketObserver: ObservableObject, WebSocketDelegate {
    /// Whether or not the client is connected.
    var isConnected: Bool { get set }
    /// The `WebSocket` instance.
    var socket: WebSocket? { get set }
    /// The key for the `clientId` assigned by the server.
    var clientIdKey: String { get }
    /// The current chat's ID
    var chatId: UUID { get set }
    /// Disconnect from the server and sever the connection.
    func disconnect()
    /// Called when the connection recieves a `Data` bloc.
    func recieved(_ data: Data)
    /// Called when the connection recieves a `String`.
    func recieved(_ text: String)
}

extension WebSocketObserver {
    
    /// The `clientId` assigned by the server.
    var clientId: UUID? {
        get {
            let uuidString = AffirmateKeychain.session[string: clientIdKey]
            return UUID(uuidString: uuidString ?? "")
        }
        set {
            if let newValue {
                AffirmateKeychain.session[string: clientIdKey] = newValue.uuidString
            } else {
                AffirmateKeychain.session[clientIdKey] = nil
            }
        }
    }
    
    /// Instantiate the `WebSocket` connection with a `URLRequest`
    func start(_ urlRequest: URLRequest) {
        socket = WebSocket(request: urlRequest)
        socket?.delegate = self
    }
    
    /// Disconnect from the server and sever the connection.
    func disconnect() {
        socket?.disconnect()
        socket = nil
    }
    
    /// Write a codable object to the server via the active `WebSocket` connection.
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

    func flushPendingConfirmationsIfPossible() async { }
    
    /// Initiate an individualized client connection.
    func connect(chatId: UUID) throws {
        self.chatId = chatId
        if let socket {
            socket.connect()
            let connect = Connect(chatId: chatId)
            try write(connect)
        }
    }
    
    /// Set `isConnected` via the MainActor.
    @MainActor func set(isConnected: Bool) {
        Task {
            clientId = nil
            if isConnected {
                clientId = UUID()
            }
            self.isConnected = isConnected
        }
    }
    
    /// Called by the `StarScream` library via the `WebSocketDelegate` conformance whenever an event is recieved from the active WebSocket connection.
    /// - Parameters:
    ///   - event: The `WebSocketEvent` that was recieved.
    ///   - client: The currently active WebSocket connection represented by an object.
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            Task {
                await self.set(isConnected: true)
                await self.flushPendingConfirmationsIfPossible()
            }
            print("WebSocket: did connect: \(headers)")

            do {
                let connect = Connect(chatId: chatId)
                try write(connect)
            } catch {
                print("Connection message failed to send:", error)
            }
        case .disconnected(let reason, let code):
            Task {
                await self.set(isConnected: false)
            }
            print("WebSocket: Did disconnect: \(reason) with code: \(code)")
        case .text(let text):
            print("WebSocket: Recieved text:", text)
            recieved(text)
        case .binary(let data):
            if let connectionConfirmation = try? data.decodeWebSocketMessage(ConfirmConnection.self) {
                clientId = nil
                clientId = connectionConfirmation.client
                Task { await self.flushPendingConfirmationsIfPossible() }
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
