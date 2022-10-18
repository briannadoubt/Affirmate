//
//  Constants.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import Foundation

enum Constants {
#if targetEnvironment(simulator) && DEBUG
    /// The URL to use when making HTTP requests from the simulator.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseURL = URL(string: "http://localhost:8080")!
    
    /// The URL to use when making WebSocket requests from the simulator.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseSocketURL = URL(string: "ws://localhost:8080")!

#elseif os(macOS) && DEBUG
    
    /// The URL to use when making HTTP requests while debugging on macOS.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseURL = URL(string: "http://localhost:8080")!
    
    /// The URL to use when making WebSocket requests while debugging on macOS.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseSocketURL = URL(string: "ws://localhost:8080")!
    
#elseif DEBUG
    
    /// The URL to use when making HTTP requests while debugging on a physical device.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseURL = URL(string: "http://10.0.0.77:8080")!
    
    /// The URL to use when making WebSocket requests while debugging on a physical device.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseSocketURL = URL(string: "ws://10.0.0.77:8080")!
    
#else
    
    /// The production URL to use when making HTTP requests.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseURL = URL(string: "https://affirmate.org")!
    
    /// The production URL to use when making WebSocket requests.
    ///
    /// The server is expected to be running with a connected database on the development machine via the same network.
    static let baseSocketURL = URL(string: "wss://affirmate.org")!
#endif
    
    enum KeyChain {
        
        enum Session {
            /// The key referencing the user's session token, stored on the KeyChain.
            static let token = "org.affirmate.keys.session.token"
            
            /// The key referencing the server's JSON Web Token, stored on the KeyChain.
            static let jwt = "org.affirmate.keys.session.jwt"
        }
        
        enum Password {
            
        }
        
        enum Chat {
            /// 
            static let publicKey = "org.affirmate.keys.chat.publicKey"
            
            ///
            static let identity = "org.affirmate.keys.chat.identity"
            
            /// The key referencing the chat's WebSocket connection's `clientId`, stored in the KeyChain.
            static let clientId = "org.affirmate.keys.chat.clientId"
            
            static let deviceIdentifier = "org.affirmate.chat.deviceIdentifier"
        }
    }
    
    enum UserDefaults {
        static let isFirstLaunch = "org.affirmate.isFirstLaunch"
    }
}
