//
//  Repository.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import Foundation

protocol Repository {
    associatedtype Object
    @discardableResult func get() async throws -> [Object]
    @discardableResult func get(id: UUID) async throws -> Object
    @discardableResult func create(_ object: Object) async throws -> Object
    @discardableResult func update(_ object: Object) async throws -> Object
    func delete(id: UUID) async throws
}
