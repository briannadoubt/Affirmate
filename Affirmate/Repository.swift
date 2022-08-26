//
//  Repository.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import Foundation

protocol Object: Codable, Equatable, Identifiable, Hashable { }

protocol GetResponse: Decodable, Hashable { }

protocol CreateObject: Codable, Hashable { }

protocol UpdateObject: Encodable, Identifiable { }

protocol Repository {
    associatedtype Response = GetResponse
    associatedtype Create = CreateObject
    associatedtype Update = UpdateObject
    func get() async throws -> [Response]
    func get(_ id: UUID) async throws -> Response
    func create(_ object: Create) async throws
    func update(_ object: Update) async throws
    func delete(_ id: UUID) async throws
}

extension Repository {
    var http: HTTPActor {
        HTTPActor()
    }
}
