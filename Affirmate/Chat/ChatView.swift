//
//  ChatView.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import SwiftUI
import ReversedScrollView

public struct ChatView: View {
    
    @EnvironmentObject var authentication: Authentication
    @EnvironmentObject var chatObserver: ChatObserver
    
    let navigationTitle: String = "Chat"
    
    @SceneStorage("newMessageText") var newMessageText = ""
    @FocusState fileprivate var focused
    
    #if os(iOS)
    @StateObject fileprivate var keyboard = KeyboardHeightObserver()
    #endif
    
    fileprivate func send() {
        Task {
            // Don't send if only whitespaces, or if message was empty
            guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            do {
                try await chatObserver.sendMessage(newMessageText)
            } catch {
                print(error)
            }
            withAnimation {
                focused = true
                newMessageText = ""
            }
        }
    }
    
    fileprivate func scrollToMessage<ID: Hashable>(_ messageId: ID, scrollProxy: ScrollViewProxy) {
        withAnimation(.spring()) {
            scrollProxy.scrollTo(messageId)
        }
    }
    
    fileprivate func scrollToLastMessage(scrollProxy: ScrollViewProxy) {
        if let message = chatObserver.chat.messages?.last {
            scrollToMessage(message.id, scrollProxy: scrollProxy)
        }
    }
    
    fileprivate func shouldHaveTail(_ message: Message) -> Bool {
        guard let messages = chatObserver.chat.messages else {
            return false
        }
        if let index = messages.firstIndex(of: message) {
            let nextMessageIndex = messages.index(after: index)
            if nextMessageIndex >= messages.count {
                return true
            }
            let nextMessage = messages[nextMessageIndex]
            if nextMessage.sender.id != message.sender.id {
                return true
            }
        }
        return false
    }
    
    public var body: some View {
        ScrollViewReader { scrollView in
            ReversedScrollView(.vertical, showsIndicator: true) {
                LazyVStack(
                    alignment: .center,
                    spacing: 0,
                    pinnedViews: [.sectionHeaders, .sectionFooters]
                ) {
                    if let currentUserId = authentication.currentUser?.id {
                        ForEach(chatObserver.chat.messages ?? []) { message in
                            MessageView(
                                currentUserId: currentUserId,
                                withTail: shouldHaveTail(message),
                                message: message
                            )
                        }
                    } else {
                        Text("You are logged in, but no user profile was found!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    scrollToLastMessage(scrollProxy: scrollView)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    if newMessageText == "" && focused {
#if os(iOS)
                        Button {
                            withAnimation {
                                focused = false
                            }
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(.spring(), value: focused)
#endif
                    }
                    TextField(
                        "New Message",
                        text: $newMessageText.animation(.spring()),
                        prompt: Text("Affirmate")
                    )
                    .focused($focused)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit(send)
                    .onChange(of: focused) { isFocused in
                        if isFocused {
                            scrollToLastMessage(scrollProxy: scrollView)
                        }
                    }
                    if newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).count > 0 {
                        ChatSendButton(send: send)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .animation(.spring(), value: focused)
                    }
                }
                .flipsForRightToLeftLayoutDirection(true)
#if os(iOS)
                .onReceive(keyboard.$height) { newHeight in
                    scrollToLastMessage(scrollProxy: scrollView)
                }
#endif
                .onChange(of: chatObserver.chat.messages?.count) { newCount in
                    scrollToLastMessage(scrollProxy: scrollView)
                }
                .padding()
                .background(.bar)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .navigationTitle("Chat")
//        .toolbar {
//            ToolbarItem(placement: .principal) {
//                if let participant = participants.first, let uid = participant.id {
//                    Menu {
//                        Button {
//                            presentedUid = uid
//                        } label: {
//                            Label("View Profile", systemImage: "person.circle.fill")
//                        }
//                    } label: {
//                        VStack(spacing: 0) {
//                            ProfileImage<U>(uid: uid)
//                                .frame(width: 20, height: 20)
//                            Text(usernames)
//                                .font(.caption2.bold())
//                                .foregroundColor(.primary)
//                        }
//                    }
//                    .menuStyle(.borderlessButton)
//                }
//            }
//        }
//        .sheet(item: $presentedUid) {
//            presentedUid = nil
//        } content: { uid in
//            if let uid = uid {
//                profileView(uid)
//            }
//        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ChatObserver(chat: Chat(name: "Meow")))
    }
}
