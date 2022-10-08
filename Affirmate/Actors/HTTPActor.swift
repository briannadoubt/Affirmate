//
//  HTTPActor.swift
//  Affirmate
//
//  Created by Bri on 8/12/22.
//

import Foundation
import Alamofire
import SwiftKeychainWrapper

actor HTTPActor {
    
    let interceptor = Interceptor()
    
    func request(_ requestConvertible: any URLRequestConvertible) async throws {
        switch await AF
            .request(requestConvertible, interceptor: interceptor)
            .validate(statusCode: [200])
            .serializingDecodable(Empty.self, emptyResponseCodes: [200])
            .result {
        case .failure(let error):
            throw error
        case .success:
            break
        }
    }
    
    func request(unauthorized requestConvertible: any URLRequestConvertible) async throws {
        switch await AF
            .request(requestConvertible)
            .validate(statusCode: [200])
            .serializingDecodable(Empty.self, emptyResponseCodes: [200])
            .result {
        case .failure(let error):
            throw error
        case .success:
            break
        }
    }
    
    func requestDecodable<Value: Decodable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async throws -> Value {
        print(type.self)
        print(requestConvertible)
        let request = AF.request(requestConvertible, interceptor: interceptor).validate()
        let result = request.serializingDecodable(type.self)
        let response = try await result.value
        print(response)
        return response
    }
    
    func requestOptionalDecodable<Value: Decodable>(_ requestConvertible: any URLRequestConvertible, to type: Value.Type) async -> Value? {
        print(type.self)
        let response = await AF
            .request(requestConvertible, interceptor: interceptor)
            .serializingDecodable(type.self)
            .response
        print(response)
        return try? response.result.get()
    }
}

extension HTTPActor {
    struct Interceptor: RequestInterceptor {
        var sessionToken: String? {
            get {
                // Get the refresh token from the keychain
                KeychainWrapper.standard.string(forKey: Constants.sessionTokenKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
            }
        }
        
        var jwtToken: String? {
            get {
                // Get the refresh token from the keychain
                KeychainWrapper.standard.string(forKey: Constants.jwtKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true)
            }
        }
        
        func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
            var request = urlRequest
            if let sessionToken = sessionToken {
                // Inject the token into requests
                request.headers.add(.authorization(bearerToken: sessionToken))
            }
            return completion(.success(request))
        }
        
//        func retry(_ request: Alamofire.Request, for session: Alamofire.Session, dueTo error: Error, completion: @escaping (Alamofire.RetryResult) -> Void) {
//            guard let sessionToken, request.response?.statusCode == 401 else {
//                return completion(.doNotRetryWithError(error))
//            }
//            Task {
//                // Inject the refresh token into request
//                do {
//                    let newToken = try await AuthenticationActor().refresh(sessionToken: sessionToken)
//                    try Self.set(newToken)
//                } catch {
//                    return completion(.doNotRetryWithError(error))
//                }
//                return completion(.retryWithDelay(1))
//            }
//        }
        
        func set(_ sessionToken: SessionToken) throws {
//            if !KeychainWrapper.standard.set(response.jwtToken, forKey: Constants.jwtKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true) {
//                throw AuthenticationError.failedToSaveTokenToKeychain
//            }
            if !KeychainWrapper.standard.set(sessionToken.value, forKey: Constants.sessionTokenKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true) {
                throw AuthenticationError.failedToSaveTokenToKeychain
            }
        }
        
        func removeTokens() throws {
//            if !KeychainWrapper.standard.removeObject(forKey: Constants.jwtKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true) {
//                throw AuthenticationError.failedToRemoveTokenFromKeychain
//            }
            if !KeychainWrapper.standard.removeObject(forKey: Constants.sessionTokenKey, withAccessibility: .afterFirstUnlock, isSynchronizable: true) {
                throw AuthenticationError.failedToRemoveTokenFromKeychain
            }
        }
    }
}
