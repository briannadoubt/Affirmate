//
//  MockUserActor.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

import AffirmateShared
@testable import Affirmate
import Foundation

actor MockUserActor: UserActable {
    static var user: UserResponse?
    static var publicUsers: [UserPublic]?
    
    var called_me = 0
    var called_find = 0
    
    var shouldFail = false
    
    func set(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    func me() async throws -> UserResponse {
        called_me += 1
        guard let user = Self.user else {
            throw MockError.noValueSet
        }
        if shouldFail {
            throw MockError.youToldMeTo
        }
        return user
    }
    
    func find(username: String?) async throws -> [UserPublic] {
        called_find += 1
        guard let publicUsers = Self.publicUsers else {
            throw MockError.noValueSet
        }
        if shouldFail {
            throw MockError.youToldMeTo
        }
        return publicUsers
    }
}
