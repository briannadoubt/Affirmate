//
//  AffirmateKeychain.swift
//  Affirmate
//
//  Created by Bri on 10/15/22.
//

import CryptoKit
import Foundation
import KeychainAccess
import SwiftUI

class AffirmateKeychain: ObservableObject {
    
    static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    static let chatService = "\(appIdentifierPrefix)org.affirmate.chat"
    static let sessionService = "\(appIdentifierPrefix)org.affirmate.session"
    static let accessGroup = "group.Affirmate"
    
    static var chat: Keychain {
        Keychain(
            service: chatService,
            accessGroup: accessGroup
        )
        .synchronizable(true)
    }
    
    static var session: Keychain {
        Keychain(
            service: sessionService,
            accessGroup: accessGroup
        )
        .synchronizable(true)
    }
    
    static var password: Keychain {
        Keychain(
            server: "https://affirmate.org/",
            protocolType: .https,
            accessGroup: accessGroup,
            authenticationType: .httpBasic
        )
        .synchronizable(true)
    }
}

