//
//  ChatActor.swift
//  Affirmate
//
//  Created by Bri on 8/9/22.
//

import Foundation
import Alamofire

actor ChatsActor: Repository {
    func get() async throws -> [Chat] {
        let chatResponses = try await http.requestDecodable(Request.chats, to: [Chat].self)
        return chatResponses
    }
    
    func get(_ id: UUID) async throws -> Chat {
        let chatResponse = try await http.requestDecodable(Request.chat(chatId: id, sessionToken: http.interceptor.sessionToken), to: Chat.self)
        return chatResponse
    }
    
    func create(_ object: Chat.Create) async throws {
        try await http.request(Request.newChat(object))
    }
    
    func update(_ object: Chat) async throws {
        
    }
    
    func delete(_ id: UUID) async throws {
        
    }
    
    func sendMessage(_ newMessage: Message.Create, chatId: UUID) async throws {
        try await http.request(Request.newMessage(chatId: chatId, message: newMessage))
    }
}
    
extension ChatsActor {
    
    enum Request: URLRequestConvertible {
        case newChat(Chat.Create)
        case chats
        case chat(chatId: UUID, sessionToken: String?)
        case newMessage(chatId: UUID, message: Message.Create)
        
        var url: URL { Constants.baseURL.appending(component: "chats") }
        
        var uri: URLConvertible? {
            switch self {
            case .chats, .newChat:
                return url
            case .chat(let chatId, _):
                return url.appending(component: chatId.uuidString)
            case let .newMessage(chatId, _):
                return url.appending(component: chatId.uuidString).appending(component: "messages")
            }
        }
        
        var method: HTTPMethod {
            switch self {
            case .chat, .chats:
                return .get
            case .newChat, .newMessage:
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
            case .chat(_, let sessionToken):
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
            case .chats:
                break
            case .chat:
                request.timeoutInterval = 3
            case let .newMessage(_, message):
                request.httpBody = try JSONEncoder().encode(message)
            case let .newChat(chat):
                request.httpBody = try JSONEncoder().encode(chat)
            }
            return request
        }
    }
}
