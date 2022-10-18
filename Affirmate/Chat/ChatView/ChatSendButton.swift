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

struct ChatSendButton_Previews: PreviewProvider {
    static var previews: some View {
        ChatSendButton(send: { print("Sent!") })
    }
}
