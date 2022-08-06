//
//  User.swift
//  AffirmateServer
//
//  Created by Bri on 7/3/22.
//

import Foundation

struct User: Decodable {
    var id: UUID?
    var firstName: String
    var lastName: String
    var username: String
    var email: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case email
    }
    
    init(from decoder: Decoder) throws {
        id = try decoder.container(keyedBy: CodingKeys.self).decode(UUID?.self, forKey: .id)
        firstName = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .firstName)
        lastName = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .lastName)
        username = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .username)
        email = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .email)
    }
    
    init(id: UUID? = nil, firstName: String, lastName: String, username: String, email: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.email = email
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
        
        func encode(to encoder: Encoder) throws {
            var container: KeyedEncodingContainer<User.Create.CodingKeys> = encoder.container(keyedBy: User.Create.CodingKeys.self)
            try container.encode(self.firstName, forKey: User.Create.CodingKeys.firstName)
            try container.encode(self.lastName, forKey: User.Create.CodingKeys.lastName)
            try container.encode(self.username, forKey: User.Create.CodingKeys.username)
            try container.encode(self.email, forKey: User.Create.CodingKeys.email)
            try container.encode(self.password, forKey: User.Create.CodingKeys.password)
            try container.encode(self.confirmPassword, forKey: User.Create.CodingKeys.confirmPassword)
        }
    }
    
    /// The get response for a user
    struct GetResponse: Decodable {
        var id: UUID?
        var firstName: String
        var lastName: String
        var username: String
        var email: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case firstName = "first_name"
            case lastName = "last_name"
            case username
            case email
        }
        
        init(from decoder: Decoder) throws {
            let container: KeyedDecodingContainer<User.GetResponse.CodingKeys> = try decoder.container(keyedBy: User.GetResponse.CodingKeys.self)
            self.id = try container.decodeIfPresent(UUID.self, forKey: User.GetResponse.CodingKeys.id)
            self.firstName = try container.decode(String.self, forKey: User.GetResponse.CodingKeys.firstName)
            self.lastName = try container.decode(String.self, forKey: User.GetResponse.CodingKeys.lastName)
            self.username = try container.decode(String.self, forKey: User.GetResponse.CodingKeys.username)
            self.email = try container.decode(String.self, forKey: User.GetResponse.CodingKeys.email)
        }
    }
}
