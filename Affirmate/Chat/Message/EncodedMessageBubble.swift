//
//  EncodedMessageBubble.swift
//  Affirmate
//
//  Created by Bri on 11/13/21.
//

import SwiftUI

//public struct MessageBubble: View {
//    
//    @EnvironmentObject var chatObserver: ChatObserver
//    
//    public init(chatId: UUID, encryptedText: String, isSender: Bool, tailPosition: MessageBubbleTailPosition = .rightBottomTrailing) {
//        self.encryptedText = encryptedText
//        self.isSender = isSender
//        self.tailPosition = tailPosition
//    }
//    
//    fileprivate var encryptedText: String
//    fileprivate var isSender: Bool
//    fileprivate var tailPosition: MessageBubbleTailPosition
//    
//    public var body: some View {
//        ZStack {
//            MessageBubbleShape(tailPosition)
//                .fill(isSender ? Color.accentColor : Color.gray)
//            Text(chatObserver.decrypt(encryptedText))
//                #if !os(watchOS)
//                .textSelection(.enabled)
//                #endif
//                .foregroundColor(.white)
//                .font(.body)
//                .padding(8)
//                .padding(.bottom, tailPosition == .none ? 8 : 10)
//                .layoutPriority(1)
//        }
//    }
//}
//
//struct EncodedMessageBubble_Previews: PreviewProvider {
//    static var previews: some View {
//        Group {
//            ForEach(MessageBubbleTailPosition.allCases) { tailPosition in
//                VStack {
//                    EncodedMessageBubble(chatId: UUID(), encryptedText: tailPosition.rawValue, isSender: true, tailPosition: tailPosition)
//                    EncodedMessageBubble(chatId: UUID(), encryptedText: tailPosition.rawValue, isSender: false, tailPosition: tailPosition)
//                }
//                .padding()
//            }
//            
//        }
//        .previewLayout(.sizeThatFits)
//    }
//}
