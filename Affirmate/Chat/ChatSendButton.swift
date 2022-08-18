//
//  ChatSendButton.swift
//  Fire/Chat
//
//  Created by Bri on 1/4/22.
//

import SwiftUI

public struct ChatSendButton: View {
    
    public init(send: @escaping () -> ()) {
        self.send = send
    }
    
    fileprivate var send: () -> ()
    
    public var body: some View {
        Button(action: send) {
            Label("Send", systemImage: "arrow.up.message.fill")
        }
    }
}

// TODO: Fix Previews
//struct ChatSendButton_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatSendButton(message: .constant("Preview message, 1...2...3... <3"), send: { print("Sent!") })
//    }
//}
