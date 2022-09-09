//
//  ChatError.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import Foundation

enum ChatError: LocalizedError {
    case failedToBuildURL
    case failedToRetrieveTokenFromKeychain
    case serverError(ServerError)
    case chatIdNotFound
    case clientIdHasNotBeenSet
    case chatWithNoOtherParticipants
    
    var errorDescription: String? {
        switch self {
        case .failedToBuildURL:
            return "Failed to build URL."
        case .failedToRetrieveTokenFromKeychain:
            return "Failed to retrieve token from Keychain."
        case .serverError(let serverError):
            return "Server Error: \(serverError.error)."
        case .chatIdNotFound:
            return "Chat ID not found."
        case .clientIdHasNotBeenSet:
            return "Client ID has not been set."
        case .chatWithNoOtherParticipants:
            return "Chat with no other participants."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .failedToBuildURL, .failedToRetrieveTokenFromKeychain:
            return "Oops, we messed up. Please try again."
        case .serverError(let serverError):
            return serverError.reason
        case .chatIdNotFound:
            return "Chat does not exist."
        case .clientIdHasNotBeenSet:
            return "We ran into an issue connecting to the chat. Please try again."
        case .chatWithNoOtherParticipants:
            return "You cannot start a chat without another participant."
        }
    }
}
