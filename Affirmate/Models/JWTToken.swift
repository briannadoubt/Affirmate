//
//  JWTToken.swift
//  Affirmate
//
//  Created by Bri on 8/12/22.
//

import Foundation
import Alamofire
import SwiftKeychainWrapper

enum JWTToken {
    struct Response: Codable {
        var jwtToken: String
        var sesionToken: String
    }
}
