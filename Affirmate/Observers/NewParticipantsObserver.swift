//
//  NewParticipantsObserver.swift
//  Affirmate
//
//  Created by Bri on 8/27/22.
//

import Alamofire
import SwiftUI

final class NewParticipantsObserver: ObservableObject {
    
    @Published var username: String = ""
    @Published var searchResults: [AffirmateUser.Public] = []
    @Published var selectedParticipants: [AffirmateUser.Public: Participant.Role] = [:]
    
    let userActor = AffirmateUserActor()
    
    @MainActor func set(searchResults: [AffirmateUser.Public]) {
        withAnimation {
            self.searchResults = searchResults
        }
    }
    
    @MainActor func select(user: AffirmateUser.Public) {
        withAnimation {
            self.selectedParticipants[user] = .participant
            self.set(searchResults: [])
        }
    }
    
    @MainActor func set(role: Participant.Role, for user: AffirmateUser.Public) {
        withAnimation {
            self.selectedParticipants[user] = role
        }
    }
    
    @MainActor func remove(user: AffirmateUser.Public) {
        withAnimation {
            self.selectedParticipants.removeValue(forKey: user)
        }
    }
    
    func find() async throws {
        let publicUsers = try await userActor.find(username: username)
        await set(searchResults: publicUsers)
    }
}
