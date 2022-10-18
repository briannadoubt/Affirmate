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

actor HTTPActor {
    
    let interceptor = Interceptor()
    
    var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
    
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
        let request = AF.request(requestConvertible, interceptor: interceptor)
            .validate(statusCode: [200])
        let response = request.serializingData(emptyResponseCodes: [200])
        let result = await response.result
        switch result {
        case .failure(let error):
            throw error
        case .success(let data):
            let jsonString = String(describing: try JSONSerialization.jsonObject(with: data))
            Logger.network.debug("Recieved data: \(jsonString)")
            let value = try JSONDecoder().decode(type.self, from: data)
            return value
        }
    }
}

extension HTTPActor {
    struct Interceptor: RequestInterceptor {
        var sessionToken: String? {
            get {
                // Get the refresh token from the keychain
                AffirmateKeychain.session[string: Constants.KeyChain.Session.token]
            }
        }
        
        var jwtToken: String? {
            get {
                // Get the refresh token from the keychain
                AffirmateKeychain.session[string: Constants.KeyChain.Session.jwt]
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
        
        func set(_ sessionToken: SessionToken) throws {
            try AffirmateKeychain.session.set(sessionToken.value, key: Constants.KeyChain.Session.token)
        }
        
        func removeTokens() throws {
            try AffirmateKeychain.session.remove(Constants.KeyChain.Session.token)
        }
    }
}
