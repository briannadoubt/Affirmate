//
//  HTTPActor.swift
//  Affirmate
//
//  Created by Bri on 8/12/22.
//

import Alamofire
import Foundation
import os.log
import KeychainAccess

protocol HTTPActable: Actor {
    var interceptor: HTTPActor.SessionTokenInterceptor { get }
    var session: Session { get }
    var keychain: Keychain { get }
    var decoder: JSONDecoder { get }
    
    init(keychain: Keychain)
    
    func request(_ requestConvertible: any URLRequestConvertible) async throws
    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws
    func requestDecodable<Value: Decodable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value
}

extension HTTPActable {
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

actor HTTPActor: HTTPActable {
    let interceptor : SessionTokenInterceptor
    let session: Session
    let keychain: Keychain
    
    init(keychain: Keychain = AffirmateKeychain.session) {
        self.session = AF
        self.keychain = keychain
        self.interceptor = SessionTokenInterceptor(keychain: keychain)
    }
    
    func request(_ requestConvertible: any URLRequestConvertible) async throws {
        switch await session
            .request(requestConvertible, interceptor: interceptor)
            .validate(statusCode: [200])
            .serializingData(emptyResponseCodes: [200])
            .result {
        case .failure(let error):
            if error.responseCode == 401 {
                // Logout
                try await AuthenticationObserver.shared.signOut(serverHasValidKey: false)
            }
            throw error
        case .success:
            break
        }
    }
    
    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws {
        switch await session
            .request(requestConvertible)
            .validate(statusCode: [200])
            .serializingData(emptyResponseCodes: [200])
            .result {
        case .failure(let error):
            throw error
        case .success:
            break
        }
    }

    func requestDecodable<Value: Decodable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value {
        let request = session.request(requestConvertible, interceptor: interceptor)
            .validate(statusCode: [200])
        let response = request.serializingData(emptyResponseCodes: [200])
        let result = await response.result
        switch result {
        case .failure(let error):
            if request.response?.statusCode == 401 {
                // Logout
                try await AuthenticationObserver.shared.signOut(serverHasValidKey: false)
            }
            throw error
        case .success(let data):
            print(data)
            let jsonString = data.base64EncodedString()
            Logger.network.debug("Recieved data: \(jsonString)")
            let value = try decoder.decode(type.self, from: data)
            return value
        }
    }
}

extension HTTPActor {
    struct SessionTokenInterceptor: RequestInterceptor {
        let keychain: Keychain
        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            var request = urlRequest
            // Get the refresh token from the keychain
            if let sessionToken = keychain[string: Constants.KeyChain.Session.token] {
                // Inject the token into requests
                request.headers.add(.authorization(bearerToken: sessionToken))
            }
            return completion(.success(request))
        }
    }
}
