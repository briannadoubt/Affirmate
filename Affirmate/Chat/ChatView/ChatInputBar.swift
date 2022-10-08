//
//  ChatInputBar.swift
//  Affirmate
//
//  Created by Bri on 9/10/22.
//

import SwiftUI

struct ChatInputBar: View {
    
    @EnvironmentObject var chatObserver: ChatObserver
    
    @SceneStorage("chat_newMessageText") var newMessageText = ""
    
    @FocusState fileprivate var focused
    
    var send: () -> ()
    
    fileprivate func scrollToMessage<ID: Hashable>(_ messageId: ID, scrollProxy: ScrollViewProxy) {
        withAnimation(.spring()) {
            scrollProxy.scrollTo(messageId)
        }
    }
    
    fileprivate func scrollToLastMessage(scrollProxy: ScrollViewProxy) {
        if let message = chatObserver.messages.last {
            scrollToMessage(message.id, scrollProxy: scrollProxy)
        }
    }
    
    var body: some View {
        HStack {
            #if os(iOS)
            if newMessageText == "" && focused {
                Button {
                    withAnimation {
                        focused = false
                    }
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
                .animation(.spring(), value: focused)
            }
            #endif
            
            #if os(watchOS)
            let text = Text("New Message")
            #else
            let text = Text("Affirmate")
            #endif
            
            TextField("New Message", text: $newMessageText.animation(.spring()), prompt: text)
            .focused($focused)
            #if !os(watchOS)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            #endif
            .onSubmit(send)
            
            #if !os(watchOS)
            if newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                ChatSendButton(send: send)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.spring(), value: focused)
            }
            #endif
        }
        .flipsForRightToLeftLayoutDirection(true)
        .padding()
        #if !os(watchOS)
        .background(.bar)
        #endif
        .ignoresSafeArea(.keyboard, edges: .bottom)

    }
}

struct ChatInputBar_Previews: PreviewProvider {
    static var previews: some View {
        ChatInputBar(send: { })
    }
}
