//
//  WebSocketObserver.swift
//  Affirmate
//
//  Created by Bri on 9/9/22.
//

import AffirmateShared
import Foundation
import Observation
import SwiftUI

/// An object that manages a WebSocket connection to a server for a View.
protocol WebSocketObserver: AnyObject, Observable {
    /// Whether or not the client is connected.
    var isConnected: Bool { get set }
    /// The `URLSessionWebSocketTask` instance.
    var socket: URLSessionWebSocketTask? { get set }
    /// The task responsible for streaming incoming messages.
    var receiveTask: Task<Void, Never>? { get set }
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

/// Errors thrown by the default WebSocketObserver implementation.
enum WebSocketObserverError: Error {
    case socketUnavailable
}

extension WebSocketObserver {
    
    /// The `clientId` assigned by the server.
    var clientId: UUID? {
        get {
            let uuidString = AffirmateKeychain.session[string: clientIdKey]
            return UUID(uuidString: uuidString ?? "")
        }
        set {
            let session = AffirmateKeychain.session
            if let newValue {
                do {
                    try session
                        .set(newValue.uuidString, key: clientIdKey)
                } catch {
                    print("Failed to set client id to keychain")
                }
            } else {
                _ = try? session
                    .remove(clientIdKey)
            }
        }
    }
    
    /// Instantiate the `WebSocket` connection with a `URLRequest`
    func start(_ urlRequest: URLRequest) {
        disconnect()
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: urlRequest)
        socket = task
        task.resume()
        receiveTask = Task {
            set(isConnected: true)
            do {
                try await connect(chatId: chatId)
            } catch {
                print("WebSocket: Failed to send connect message:", error)
            }
            do {
                try await streamMessages(from: task)
            } catch {
                print("WebSocket: Stream ended with error:", error)
            }
            set(isConnected: false)
        }
    }
    
    /// Disconnect from the server and sever the connection.
    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }
    
    /// Write a codable object to the server via the active `WebSocket` connection.
    func write<T: Codable & Sendable>(_ data: T) async throws {
        guard let clientId else {
            clientId = nil
            clientId = UUID()
            try await write(data)
            return
        }
        let webSocketMessage = WebSocketMessage<T>(client: clientId, data: data)
        guard let socket else {
            throw WebSocketObserverError.socketUnavailable
        }
        try await socket.send(.data(JSONEncoder().encode(webSocketMessage)))
        print("Did write", T.self, "from client with ID", clientId)
    }

    func flushPendingConfirmationsIfPossible() async { }
    
    /// Initiate an individualized client connection.
    func connect(chatId: UUID) async throws {
        self.chatId = chatId
        let connect = Connect(chatId: chatId)
        try await write(connect)
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
}

private extension WebSocketObserver {
    func streamMessages(from task: URLSessionWebSocketTask) async throws {
        let stream = AsyncThrowingStream<URLSessionWebSocketTask.Message, Error> { continuation in
            let producer = Task {
                while !Task.isCancelled {
                    do {
                        let message = try await task.receive()
                        continuation.yield(message)
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
        do {
            for try await message in stream {
                await handle(message: message)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    func handle(message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .data(let data):
            await handle(data: data)
        case .string(let text):
            print("WebSocket: Recieved text:", text)
            recieved(text)
        @unknown default:
            break
        }
    }

    func handle(data: Data) async {
        if let connectionConfirmation = try? data.decodeWebSocketMessage(ConfirmConnection.self) {
            clientId = nil
            clientId = connectionConfirmation.client
            await flushPendingConfirmationsIfPossible()
            print("WebSocket: Connection confirmed!")
        } else if let webSocketError = try? JSONDecoder().decode(WebSocketError.self, from: data) {
            print("Recieved webSocket server error:", webSocketError)
        } else {
            print("WebSocket: Recieved data")
            recieved(data)
        }
    }
}
