//
//  WebSocket.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// A message identifying which clent the message was intended for, and a codable object.
public struct WebSocketMessage<T: Codable>: Codable {
    /// The client that the message was intended for.
    public let client: UUID
    /// The data of the message.
    public let data: T
    
    /// A message identifying which clent the message was intended for, and a codable object.
    /// - Parameters:
    ///   - client: The client that the message was intended for.
    ///   - data: The data of the message.
    public init(client: UUID, data: T) {
        self.client = client
        self.data = data
    }
}

/// A request from the client to the server to connect to a chat, to confirm the websocket connection has been established.
public struct Connect: Codable, Hashable, Equatable {
    /// The chat to connect to.
    public let chatId: UUID
    
    /// A request from the client to the server to connect to a chat, to confirm the websocket connection has been established.
    /// - Parameter chatId: The chat to connect to.
    public init(chatId: UUID) {
        self.chatId = chatId
    }
}

/// An object used to confirm whether or not a connection was established.
public struct ConfirmConnection: Codable {
    /// Whether or not the connection was established.
    public var connected: Bool
    
    /// An object used to confirm whether or not a connection was established.
    /// - Parameter connected: Whether or not the connection was established.
    public init(connected: Bool) {
        self.connected = connected
    }
}
