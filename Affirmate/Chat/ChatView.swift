//
//  ChatView.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import SwiftUI
import ReversedScrollView
import UniformTypeIdentifiers

public struct ChatView: View {
    
    @EnvironmentObject var authentication: Authentication
    @EnvironmentObject var chatObserver: ChatObserver
    
    @SceneStorage("chat_newMessageText") var newMessageText = ""
    @SceneStorage("chat_showingNewParticipants") var showingNewParticipants = false
    @FocusState fileprivate var focused
    
    @State var presentedParticipant: Participant?
    @State var presentedCopiedUrl = false
    
    #if os(iOS)
    @StateObject fileprivate var keyboard = KeyboardHeightObserver()
    #endif
    
    fileprivate func send() {
        // Don't send if only whitespaces, or if message was empty
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        do {
            try chatObserver.sendMessage(newMessageText)
        } catch {
            print(error)
        }
        withAnimation {
            focused = true
            newMessageText = ""
        }
    }
    
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
    
    fileprivate func shouldHaveTail(_ message: Message) -> Bool {
        let messages = chatObserver.messages
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
                        ForEach(chatObserver.messages) { message in
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
                .onChange(of: chatObserver.messages.count) { newCount in
                    scrollToLastMessage(scrollProxy: scrollView)
                }
                .padding()
                .background(.bar)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .toolbarTitleMenu {
                ForEach(chatObserver.participants) { participant in
                    HStack {
                        Circle().frame(width: 44, height: 44)
                        Text("@" + participant.username)
                    }
                }
                Button {
                    showingNewParticipants = true
                } label: {
                    Label("New Participant", systemImage: "plus.message")
                }
            }
            .sheet(isPresented: $showingNewParticipants) {
                NewParticipantsView()
                    .environmentObject(chatObserver)
            }
        }
        .navigationTitle(chatObserver.name)
        .task {
            do {
                try chatObserver.connect()
            } catch {
                print("TODO: Show this error in the UI:", "Connection Error:", error)
            }
        }
        .toolbar {
            ToolbarTitleMenu()
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    UIPasteboard.general.setValue(chatObserver.shareableUrl, forPasteboardType: UTType.url.identifier)
                    withAnimation {
                        presentedCopiedUrl = true
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
        .alert(isPresented: $presentedCopiedUrl) {
            Alert(title: Text("Link Copied!"), message: Text(""))
        }
        .sheet(item: $presentedParticipant) {
            presentedParticipant = nil
        } content: { participant in
            if let presentedParticipant {
                ProfileView(user: presentedParticipant.user)
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ChatObserver(chat: Chat(id: UUID(), name: "Meow")))
    }
}
