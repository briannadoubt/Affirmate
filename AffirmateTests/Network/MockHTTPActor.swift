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
import Alamofire
import Foundation
import KeychainAccess

actor MockHTTPActor: HTTPActable {
    var interceptor: HTTPActor.SessionTokenInterceptor
    var session: Session
    var keychain: Keychain
    
    var called_request = 0
    var called_request_unauthorized = 0
    var called_requestDecodable = 0
    
    var result: (any Decodable)?
    func set(result: (any Decodable)?) {
        self.result = result
    }
    
    var shouldFail = false
    func set(shouldFail: Bool) {
        self.shouldFail = shouldFail
    }
    
    init(keychain: Keychain = AffirmateKeychain.session) {
        let configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockURLProtocol.self] + (configuration.protocolClasses ?? [])
        self.session = Session(configuration: configuration)
        self.keychain = keychain
        self.interceptor = HTTPActor.SessionTokenInterceptor(keychain: keychain)
    }
    
    func request(_ requestConvertible: URLRequestConvertible) async throws {
        called_request += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }
    
    func request(unauthorized requestConvertible: URLRequestConvertible) async throws {
        called_request_unauthorized += 1
        if shouldFail {
            throw MockError.youToldMeTo
        }
    }
    
    func requestDecodable<Value: Decodable>(_ requestConvertible: URLRequestConvertible, to type: Value.Type) async throws -> Value {
        called_requestDecodable += 1
        guard let result = result as? Value else {
            throw MockError.noValueSet
        }
        if shouldFail {
            throw MockError.youToldMeTo
        }
        return result
    }
}
