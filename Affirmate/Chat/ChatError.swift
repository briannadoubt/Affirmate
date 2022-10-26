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
    case failedToConvertMessageContentIntoData
    case nonexistentEntityName
    case participantIdNotFound
    case entityNotFound
    case messageIdNotFound
    
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
        case .failedToConvertMessageContentIntoData:
            return "Failed to convert message content into data."
        case .nonexistentEntityName:
            return "The requested entity name does not exist."
        case .participantIdNotFound:
            return "The cached participant doesn't have an associated id."
        case .entityNotFound:
            return "The entity was not found when querying CoreData."
        case .messageIdNotFound:
            return "Message ID not found."
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
        case .failedToConvertMessageContentIntoData:
            return "Failed to encrypt message."
        case .nonexistentEntityName:
            return "Oops, we had an issue loading data from the local cache."
        case .participantIdNotFound:
            return "Oops, looks like there's some corrupted data. Reloading the chat and try again."
        case .entityNotFound:
            return "Looks like that doesn't exist on your device."
        case .messageIdNotFound:
            return "Message not found."
        }
    }
}
