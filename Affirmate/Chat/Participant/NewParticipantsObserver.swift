//
//  NewParticipantsObserver.swift
//  Affirmate
//
//  Created by Bri on 8/27/22.
//

import AffirmateShared
import Observation
import SwiftUI

@MainActor
@Observable
final class NewParticipantsObserver {

    var username: String = ""
    var searchResults: [UserPublic] = []
    var selectedParticipants: [UUID: (user: UserPublic, role: ParticipantRole)] = [:]
    
    let userActor = UserActor()
    
    @MainActor func set(searchResults: [UserPublic]) {
        self.searchResults = searchResults
    }
    
    @MainActor func select(user: UserPublic) {
        self.selectedParticipants[user.id] = (user: user, role: .participant)
        self.set(searchResults: [])
    }
    
    @MainActor func set(role: ParticipantRole, for user: UserPublic) {
        self.selectedParticipants[user.id] = (user: user, role: role)
    }
    
    @MainActor func remove(user: UserPublic) {
        self.selectedParticipants.removeValue(forKey: user.id)
    }
    
    @concurrent
    func find() async throws {
        let publicUsers = try await userActor.find(username: username)
        await set(searchResults: publicUsers)
    }
}
