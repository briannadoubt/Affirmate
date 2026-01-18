//
//  MockHTTPActor.swift
//  AffirmateTests
//
//  Created by Bri on 11/22/22.
//

#if os(watchOS)
@testable import AffirmateWatch
#else
@testable import Affirmate
#endif
import Foundation

actor MockHTTPActor: HTTPActable {
    let session: URLSession
    let keychain: Keychain

    var called_request = 0
    var called_request_unauthorized = 0
    var called_requestDecodable = 0

    private var result: (any Decodable)?
    private var shouldFail = false

    init(keychain: Keychain = AffirmateKeychain.session, session: URLSession = .shared) {
        self.session = session
        self.keychain = keychain
    }

    convenience init(keychain: Keychain = AffirmateKeychain.session) {
        self.init(keychain: keychain, session: .shared)
    }

    func set(result: (any Decodable)?) {
        self.result = result
    }

    func set(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }

    func request(_ requestConvertible: any URLRequestConvertible) async throws {
        called_request += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }

    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws {
        called_request_unauthorized += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }

    func requestDecodable<Value: Decodable & Sendable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value {
        called_requestDecodable += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
        guard let value = result as? Value else {
            throw MockError.noValueSet
        }
        return value
    }
}
