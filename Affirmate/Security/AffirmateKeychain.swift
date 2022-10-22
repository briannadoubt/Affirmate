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
    
    private static let appIdentifierPrefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String
    
    private static let chatService = "\(appIdentifierPrefix)org.affirmate.chat"
    private static let sessionService = "\(appIdentifierPrefix)org.affirmate.session"
    private static let accessGroup = "group.Affirmate"
    
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

