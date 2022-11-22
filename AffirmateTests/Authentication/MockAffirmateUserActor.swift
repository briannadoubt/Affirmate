//
//  MockUserActor.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

@testable import Affirmate
import Foundation

actor MockUserActor: UserActable {
    static var user: User?
    static var publicUsers: [User.Public]?
    
    var called_me = 0
    var called_find = 0
    
    func me() async throws -> User {
        called_me += 1
        guard let user = Self.user else {
            throw MockError.noValueSet
        }
        return user
    }
    
    func find(username: String?) async throws -> [User.Public] {
        called_find += 1
        guard let publicUsers = Self.publicUsers else {
            throw MockError.noValueSet
        }
        return publicUsers
    }
}
