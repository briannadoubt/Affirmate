//
//  ChatActor.swift
//  Affirmate
//
//  Created by Bri on 8/9/22.
//

import AffirmateShared
import Foundation
import Alamofire
import KeychainAccess

actor ChatActor {
    let http: HTTPActable
    let keychain: Keychain
    
    init(http: HTTPActable = HTTPActor(), keychain: Keychain = AffirmateKeychain.session) {
        self.http = http
        self.keychain = keychain
    }
    
    var sessionToken: String? {
        keychain[Constants.KeyChain.Session.token]
    }
    
    func getSessionToken() -> String? {
        sessionToken
    }
    
    func get() async throws -> [ChatResponse] {
        let chatResponses = try await http.requestDecodable(Request.chats, to: [ChatResponse].self)
        return chatResponses
    }
    
    func get(_ id: UUID) async throws -> ChatResponse {
        let chatResponse = try await http.requestDecodable(Request.chat(chatId: id, sessionToken: sessionToken), to: ChatResponse.self)
        return chatResponse
    }
    
    func create(_ object: ChatCreate) async throws {
        try await http.request(Request.newChat(object))
    }
    
    func joinChat(_ chatId: UUID, confirmation: ChatInvitationJoin) async throws {
        try await http.request(Request.joinChat(chatId: chatId, confirmation: confirmation, sessionToken: sessionToken))
    }
    
    func declineInvitation(_ chatId: UUID, declination: ChatInvitationDecline) async throws {
        try await http.request(Request.declineInvitation(chatId: chatId, declination: declination, sessionToken: sessionToken))
    }
}
    
extension ChatActor {
    
    enum Request: URLRequestConvertible {
        case newChat(ChatCreate)
        case chats
        case chat(chatId: UUID, sessionToken: String?)
        
        case joinChat(chatId: UUID, confirmation: ChatInvitationJoin, sessionToken: String?)
        case declineInvitation(chatId: UUID, declination: ChatInvitationDecline, sessionToken: String?)
        
        #if os(macOS)
        var url: URL { Constants.baseURL.appendingPathComponent("chats") }
        #else
        var url: URL { Constants.baseURL.appending(component: "chats") }
        #endif
        
        #if os(macOS)
        var uri: URLConvertible? {
            switch self {
            case .chats, .newChat:
                return url
            case .chat(let chatId, _):
                return url.appendingPathComponent(chatId.uuidString)
            case .joinChat(let chatId, _, _):
                return url.appendingPathComponent(chatId.uuidString).appendingPathComponent("join")
            case .declineInvitation(let chatId, _, _):
                return url.appendingPathComponent(chatId.uuidString).appendingPathComponent("decline")
            }
        }
        #else
        var uri: URLConvertible? {
            switch self {
            case .chats, .newChat:
                return url
            case .chat(let chatId, _):
                return url.appending(component: chatId.uuidString)
            case .joinChat(let chatId, _, _):
                return url.appending(component: chatId.uuidString).appending(component: "join")
            case .declineInvitation(let chatId, _, _):
                return url.appending(component: chatId.uuidString).appending(component: "decline")
            }
        }
        #endif
        
        var method: HTTPMethod {
            switch self {
            case .chat, .chats:
                return .get
            case .newChat, .joinChat, .declineInvitation:
                return .post
            }
        }
        
        var headers: HTTPHeaders {
            var headers = HTTPHeaders()
            headers.add(.defaultAcceptLanguage)
            headers.add(.defaultUserAgent)
            headers.add(.defaultAcceptEncoding)
            headers.add(.contentType("application/json"))
            headers.add(.accept("application/json"))
            switch self {
            case .chat(_, let sessionToken),
                 .joinChat(_, _, let sessionToken),
                 .declineInvitation(_, _, let sessionToken):
                if let sessionToken {
                    headers.add(.authorization(bearerToken: sessionToken))
                }
            default: break
            }
            return headers
        }
        
        func asURLRequest() throws -> URLRequest {
            guard let requestURL = uri else {
                throw ChatError.failedToBuildURL
            }
            var request = try URLRequest(url: requestURL, method: method, headers: headers)
            switch self {
            case .chats, .chat:
                break
            case let .newChat(chat):
                request.httpBody = try JSONEncoder().encode(chat)
            case .joinChat(_, let confirmation, _):
                request.httpBody = try JSONEncoder().encode(confirmation)
            case .declineInvitation(_, let declination, _):
                request.httpBody = try JSONEncoder().encode(declination)
            }
            return request
        }
    }
}
