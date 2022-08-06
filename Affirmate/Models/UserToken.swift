//
//  UserToken.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct UserToken: Decodable {
    var id: UUID?
    var value: String
    var expiresAt: Date
    var user: User
}
