//
//  MessageBubble.swift
//  Affirmate
//
//  Created by Bri on 11/13/21.
//

import SwiftUI

public struct MessageBubble: View {
    
    public init(text: String, isSender: Bool, tailPosition: MessageBubbleTailPosition = .rightBottomTrailing) {
        self.text = text
        self.isSender = isSender
        self.tailPosition = tailPosition
    }
    
    fileprivate var text: String
    fileprivate var isSender: Bool
    fileprivate var tailPosition: MessageBubbleTailPosition
    
    public var body: some View {
        ZStack {
            MessageBubbleShape(tailPosition)
                .fill(isSender ? Color.accentColor : Color.gray)
            Text(text)
                #if !os(watchOS)
                .textSelection(.enabled)
                #endif
                .foregroundColor(.white)
                .font(.body)
                .padding(8)
                .padding(.bottom, tailPosition == .none ? 8 : 10)
                .layoutPriority(1)
        }
    }
}

struct MessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ForEach(MessageBubbleTailPosition.allCases) { tailPosition in
                VStack {
                    MessageBubble(text: tailPosition.rawValue, isSender: true, tailPosition: tailPosition)
                    MessageBubble(text: tailPosition.rawValue, isSender: false, tailPosition: tailPosition)
                }
                .padding()
            }
            
        }
        .previewLayout(.sizeThatFits)
    }
}
