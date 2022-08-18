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
        let chatResponse = try await http.requestDecodable(Request.chat(chatId: id), to: Chat.self)
        return chatResponse
    }
    
    func create(_ object: Chat.Create) async throws {
        try await http.request(Request.newChat(object))
    }
    
    func update(_ object: Chat) async throws {
        
    }
    
    func delete(_ id: UUID) async throws {
        
    }
    
    func sendMessage(_ text: String, chatId: UUID) async throws {
        let newMessage = Message.Create(text: text)
        try await http.request(Request.newMessage(chatId: chatId, message: newMessage))
    }
}
    
extension ChatsActor {
    
    private enum Request: URLRequestConvertible {
        case newChat(Chat.Create)
        case chats
        case chat(chatId: UUID)
        case newMessage(chatId: UUID, message: Message.Create)
        
        var url: URL? { Constants.baseURL?.appending(component: "chats") }
        
        var uri: URLConvertible? {
            switch self {
            case .chats, .newChat:
                return url
            case .chat(let chatId):
                return url?.appending(component: chatId.uuidString)
            case let .newMessage(chatId, _):
                return url?.appending(component: chatId.uuidString).appending(component: "messages")
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
            case let .newMessage(_, message):
                request.httpBody = try JSONEncoder().encode(message)
            case let .newChat(chat):
                request.httpBody = try JSONEncoder().encode(chat)
            }
            return request
        }
    }
}
