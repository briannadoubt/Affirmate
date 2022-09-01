//
//  NewParticipantObserver.swift
//  Affirmate
//
//  Created by Bri on 8/27/22.
//

import Alamofire
import SwiftUI

final class NewParticipantObserver: ObservableObject {
    
    @Published var username: String = ""
    @Published var searchResults: [User.Public] = []
    @Published var selectedParticipants: [User.Public: Participant.Role] = [:]
    
    let userActor = UserActor()
    
    @MainActor func set(_ searchResults: [User.Public]) {
        withAnimation {
            self.searchResults = searchResults
        }
    }
    
    @MainActor func select(user: User.Public) {
        withAnimation {
            self.selectedParticipants[user] = .participant
        }
    }
    
    @MainActor func set(role: Participant.Role, for user: User.Public) {
        withAnimation {
            self.selectedParticipants[user] = role
        }
    }
    
    @MainActor func remove(user: User.Public) {
        withAnimation {
            self.selectedParticipants.removeValue(forKey: user)
        }
    }
    
    func find() async throws {
        let publicUsers = try await userActor.find(username: username)
        await set(publicUsers)
    }
}
