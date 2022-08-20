//
//  User.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Foundation

struct User: Object {
    var id: UUID?
    var firstName: String
    var lastName: String
    var username: String
    var email: String
    
//    enum CodingKeys: String, CodingKey {
//        case id
//        case firstName = "first_name"
//        case lastName = "last_name"
//        case username
//        case email
//    }
    
    init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
    }
    
    struct LoginResponse: Decodable {
        var jwt: JWTToken.Response
        var user: User
    }
    
    /// The post parameter used to create a new user
    struct Create: Encodable {
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        var password: String
        var confirmPassword: String
        
        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case username
            case email
            case password
            case confirmPassword = "confirm_password"
        }
    }
}
