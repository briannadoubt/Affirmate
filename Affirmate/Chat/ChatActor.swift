//
//  ChatActor.swift
//  Affirmate
//
//  Created by Bri on 8/9/22.
//

import Foundation
import Alamofire

actor ChatActor: Repository {
    func get() async throws -> [Chat.GetResponse] {
        let chatResponses = try await http.requestDecodable(Request.chats, to: [Chat.GetResponse].self)
        return chatResponses
    }
    
    func get(_ id: UUID) async throws -> Chat.GetResponse {
        let chatResponse = try await http.requestDecodable(Request.chat(chatId: id, sessionToken: http.interceptor.sessionToken), to: Chat.GetResponse.self)
        return chatResponse
    }
    
    func create(_ object: Chat.Create) async throws {
        try await http.request(Request.newChat(object))
    }
    
//    func invite(_ )
    
    func joinChat(_ chatId: UUID, confirmation: ChatInvitation.Join) async throws {
        try await http.request(Request.joinChat(chatId: chatId, confirmation: confirmation, sessionToken: http.interceptor.sessionToken))
    }
    
    func declineInvitation(_ chatId: UUID, declination: ChatInvitation.Decline) async throws {
        try await http.request(Request.declineInvitation(chatId: chatId, declination: declination, sessionToken: http.interceptor.sessionToken))
    }
}
    
extension ChatActor {
    
    enum Request: URLRequestConvertible {
        case newChat(Chat.Create)
        case chats
        case chat(chatId: UUID, sessionToken: String?)
        
        case joinChat(chatId: UUID, confirmation: ChatInvitation.Join, sessionToken: String?)
        case declineInvitation(chatId: UUID, declination: ChatInvitation.Decline, sessionToken: String?)
        
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
