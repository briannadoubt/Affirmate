//
//  MessageBubbleTailPosition.swift
//  Chat/Message
//
//  Created by Bri on 1/14/22.
//

import Foundation

public enum MessageBubbleTailPosition: String, CaseIterable, Identifiable {
    
    /// Tail is on bottom left of bubble and swoops to the left.
    /// This is the default for a chat UI representing anyone that is not the user
    case leftBottomLeading
    
    /// Tail is on bottom right of bubble and swoops to the left.
    case leftBottomTrailing
    
    /// Tail is on top left of bubble and swoops to the left.
    case leftTopLeading
    
    /// Tail is on top right of bubble and swoops to the left.
    case leftTopTrailing
    
    /// Tail is on bottom left of bubble and swoops to the right.
    case rightBottomLeading
    
    /// Tail is on bottom right of bubble and swoops to the right.
    /// This is the default for a chat UI representing the user
    case rightBottomTrailing
    
    /// Tail is on top left of bubble and swoops to the right.
    case rightTopLeading
    
    /// Tail is on top right of bubble and swoops to the right.
    case rightTopTrailing
    
    case none
    
    public var id: String { rawValue }
    
    var isOnTop: Bool? {
        switch self {
        case .leftBottomLeading, .leftBottomTrailing, .rightBottomLeading, .rightBottomTrailing:
            return false
        case .leftTopLeading, .leftTopTrailing, .rightTopLeading, .rightTopTrailing:
            return true
        case .none:
            return nil
        }
    }
    
    var isLeading: Bool? {
        switch self {
        case .leftBottomLeading, .leftTopLeading, .rightBottomLeading, .rightTopLeading:
            return true
        case .leftBottomTrailing, .leftTopTrailing, .rightBottomTrailing, .rightTopTrailing:
            return false
        case .none:
            return nil
        }
    }
    
    /// This is the default for a chat UI representing the user
    static var sender: MessageBubbleTailPosition {
        .rightBottomTrailing
    }
    
    /// This is the default for a chat UI representing anyone that is not the user
    static var reciever: MessageBubbleTailPosition {
        .leftBottomLeading
    }
}
