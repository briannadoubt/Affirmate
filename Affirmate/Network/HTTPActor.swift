//
//  HTTPActor.swift
//  Affirmate
//
//  Created by Bri on 8/12/22.
//

import Foundation
import os.log

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

struct HTTPHeader: Sendable {
    let name: String
    let value: String

    static func authorization(bearerToken: String) -> HTTPHeader {
        HTTPHeader(name: "Authorization", value: "Bearer \(bearerToken)")
    }

    static func authorization(username: String, password: String) -> HTTPHeader {
        guard let data = "\(username):\(password)".data(using: .utf8) else {
            return HTTPHeader(name: "Authorization", value: "")
        }
        let credential = data.base64EncodedString()
        return HTTPHeader(name: "Authorization", value: "Basic \(credential)")
    }
}

struct HTTPHeaders: Sendable {
    private var storage: [String: String] = [:]

    subscript(name: String) -> String? {
        get { storage[name] }
        set { storage[name] = newValue }
    }

    mutating func add(_ header: HTTPHeader) {
        storage[header.name] = header.value
    }

    func apply(to request: inout URLRequest) {
        for (name, value) in storage {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    mutating func addJSONDefaults() {
        storage["Accept-Language"] = "en"
        storage["User-Agent"] = "Affirmate/1.0"
        storage["Accept-Encoding"] = "gzip;q=1.0, compress;q=0.5"
        storage["Content-Type"] = "application/json"
        storage["Accept"] = "application/json"
    }
}

/// Minimal replacement for Alamofire's URLRequestConvertible.
protocol URLRequestConvertible: Sendable {
    @MainActor
    func asURLRequest() throws -> URLRequest
}

protocol HTTPActable: Actor {
    var session: URLSession { get }
    var keychain: Keychain { get }
    var decoder: JSONDecoder { get }

    init(keychain: Keychain, session: URLSession)

    func request(_ requestConvertible: any URLRequestConvertible) async throws
    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws
    func requestDecodable<Value: Decodable & Sendable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value
}

extension HTTPActable {
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum HTTPActorError: Error, Sendable {
    case invalidResponse
    case unacceptableStatusCode(Int, Data)
}

actor HTTPActor: HTTPActable {
    let session: URLSession
    let keychain: Keychain
    private let logger = Logger(subsystem: "Affirmate.network", category: "http")

    init(keychain: Keychain = AffirmateKeychain.session, session: URLSession = .shared) {
        self.session = session
        self.keychain = keychain
    }

    func request(_ requestConvertible: any URLRequestConvertible) async throws {
        let request = try await buildRequest(from: requestConvertible, authorized: true)
        _ = try await perform(request: request, acceptedStatusCodes: [200, 204], shouldLogoutOnUnauthorized: true)
    }

    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws {
        let request = try await buildRequest(from: requestConvertible, authorized: false)
        _ = try await perform(request: request, acceptedStatusCodes: [200, 204], shouldLogoutOnUnauthorized: false)
    }

    func requestDecodable<Value: Decodable & Sendable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value {
        let request = try await buildRequest(from: requestConvertible, authorized: true)
        let data = try await perform(request: request, acceptedStatusCodes: [200], shouldLogoutOnUnauthorized: true)
        logger.debug("Received data: \(data.base64EncodedString())")
        return try decoder.decode(Value.self, from: data)
    }
}

private extension HTTPActor {
    @discardableResult
    func perform(request: URLRequest, acceptedStatusCodes: Set<Int>, shouldLogoutOnUnauthorized: Bool) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try await validate(response: response, data: data, acceptedStatusCodes: acceptedStatusCodes, shouldLogoutOnUnauthorized: shouldLogoutOnUnauthorized)
        return data
    }

    func buildRequest(from requestConvertible: any URLRequestConvertible, authorized: Bool) async throws -> URLRequest {
        var request = try await MainActor.run {
            try requestConvertible.asURLRequest()
        }
        if authorized, let sessionToken = keychain[string: Constants.KeyChain.Session.token] {
            request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func validate(response: URLResponse, data: Data, acceptedStatusCodes: Set<Int>, shouldLogoutOnUnauthorized: Bool) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPActorError.invalidResponse
        }
        guard acceptedStatusCodes.contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401, shouldLogoutOnUnauthorized {
                try await AuthenticationObserver.shared.signOut(serverHasValidKey: false)
            }
            throw HTTPActorError.unacceptableStatusCode(httpResponse.statusCode, data)
        }
    }
}
