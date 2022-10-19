//
//  AffirmateKeychain.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import CryptoKit
import Foundation
import KeychainAccess
import SignalProtocol
import SwiftUI

class AffirmateKeychain: ObservableObject {
    
    static var chat: Keychain {
        Keychain(
            service: "LU6454UVH5.org.affirmate.chat",
            accessGroup: "group.Affirmate"
        )
        .synchronizable(true)
    }
    
    static var session: Keychain {
        Keychain(
            service: "LU6454UVH5.org.affirmate.session",
            accessGroup: "group.Affirmate"
        )
        .synchronizable(true)
    }
    
    static var password: Keychain {
        Keychain(
            server: "https://affirmate.org/",
            protocolType: .https,
            accessGroup: "group.Affirmate",
            authenticationType: .httpBasic
        )
        .synchronizable(true)
    }
}

