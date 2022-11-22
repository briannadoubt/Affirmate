//
//  SessionToken.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

/// The response representing a SessionToken
public struct SessionTokenResponse: Codable {
    /// The id in the database
    public var id: UUID
    /// The value of the token
    public var value: String
    
    /// The response representing a SessionToken
    /// - Parameters:
    ///   - id: The id in the database
    ///   - value: The value of the token
    public init(id: UUID, value: String) {
        self.id = id
        self.value = value
    }
}
