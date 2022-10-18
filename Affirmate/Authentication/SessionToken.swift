//
//  SessionToken.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

struct SessionToken: Codable {
    var id: UUID
    var value: String
    var user: AffirmateUser.SessionTokenResponse
}
