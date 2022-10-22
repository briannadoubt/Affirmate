//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation

extension Message {
    
    struct GetResponse: IdentifiableObject {
        
        static func == (lhs: GetResponse, rhs: GetResponse) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: UUID
        var text: Sealed
        var chat: Chat.MessageResponse
        var sender: Participant.GetResponse
        var recipient: Participant.GetResponse
        var created: Date?
        var updated: Date?
    }

    struct Sealed: Codable, Hashable {
        var ephemeralPublicKeyData: Data
        var ciphertext: Data
        var signature: Data
    }
    
    struct Create: Codable {
        var sealed: Sealed
        var recipient: UUID
    }

}

