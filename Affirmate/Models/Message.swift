//
//  Message.swift
//  AffirmateServer
//
//  Created by Bri on 7/30/22.
//

import Foundation
//import AppIntents

struct Message: Object {
    var id: UUID
    var text: String?
    var chat: Chat.MessageResponse
    var sender: Participant.GetResponse

    struct Create: Codable {
        var text: String
    }
    
    static var notificationName = Notification.Name("NewMessage")
}

//extension Message {
//    
//    struct SendIntent: AppIntent {
//        
//        typealias PerformResult = Result<Message, ChatError>
//        typealias SummaryContent = Summary
//        
//        static var title: LocalizedStringResource = "Send a message"
//        static var description = IntentDescription("Sends a message to the specified Affirmate chat.")
//        static var parameterSummary: Summary {
//            Summary("Send a new message to @\(\.$senderUsername) that says \(\.$text)")
//        }
//        
//        @Parameter(title: "text") var text: String
//        @Parameter(title: "chat_id", optionsProvider: Chat.OptionsProvider()) var chatId: String
//        
//        func perform() async throws -> Result<Message, ChatError> {
//            let newMessage = try await ChatActor().sendMessage(text, chatId: chatId)
//            return .finished(value: newMessage)
//        }
//    }
//    
//    struct Entity: AppEntity {
//        
//        static var typeDisplayRepresentation: TypeDisplayRepresentation
//        
//        static var typeDisplayRepresentation = "message"
//        
//        var message: Message
//        var chat: Chat
//        
//        var id: UUID? { private set { message.id } }
//        
//        var displayRepresentation: DisplayRepresentation {
//            DisplayRepresentation(
//                title: "\(chat.name): New message",
//                subtitle: message.text,
//                image: DisplayRepresentation.Image.init(url: message.imageURLs?.first)
//            )
//        }
//    }
//    
//    struct Query: EntityQuery {
//        func entities(for identifiers: [Message.Entity.ID]) async throws -> [Message.Entity] {
//            
//        }
//    }
//}
