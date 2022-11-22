//
//  ChatError.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import Foundation

public enum ChatError: LocalizedError {
    case failedToBuildURL
    case chatIdNotFound
    case clientIdHasNotBeenSet
    case chatWithNoOtherParticipants
    case preKeyNotFound
    case preKeyDoesNotHaveAssociatedInvitation
    
    public var errorDescription: String? {
        switch self {
        case .failedToBuildURL:
            return "Failed to build URL."
        case .chatIdNotFound:
            return "Chat ID not found."
        case .clientIdHasNotBeenSet:
            return "Client ID has not been set."
        case .chatWithNoOtherParticipants:
            return "Chat with no other participants."
        case .preKeyNotFound:
            return "PreKey not found."
        case .preKeyDoesNotHaveAssociatedInvitation:
            return "PreKey does not have an associated chat invitation."
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .failedToBuildURL:
            return "Oops, we messed up. Please try again."
        case .chatIdNotFound:
            return "Chat does not exist."
        case .clientIdHasNotBeenSet:
            return "We ran into an issue connecting to the chat. Please try again."
        case .chatWithNoOtherParticipants:
            return "You cannot start a chat without another participant."
        case .preKeyNotFound:
            return "This chat has not been set up!"
        case .preKeyDoesNotHaveAssociatedInvitation:
            return "Invalid cryptographic credentials."
        }
    }
}
