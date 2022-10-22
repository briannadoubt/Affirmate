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
    
    @EnvironmentObject var authentication: AuthenticationObserver
    @EnvironmentObject var chatObserver: ChatObserver
    
    @SceneStorage("chat_newMessageText") var newMessageText = ""
    @SceneStorage("chat_showingNewParticipants") var showingNewParticipants = false
    
    @State var presentedParticipant: Participant.GetResponse?
    @State var presentedCopiedUrl = false
    
    #if os(iOS)
    @StateObject fileprivate var keyboard = KeyboardHeightObserver()
    #endif
    
    @FocusState fileprivate var focused
    
    fileprivate func send() {
        Task {
            // Don't send if only whitespaces, or if message was empty
            guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            // TODO: Verify (with science) whether there are "not allowed" words in the message.
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
        if let message = chatObserver.messages.last {
            scrollToMessage(message.id, scrollProxy: scrollProxy)
        }
    }
    
    fileprivate func shouldHaveTail(_ message: Message.GetResponse) -> Bool {
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
    
    var currentParticipantId: UUID? {
        guard
            let currentParticipant = chatObserver
                .participants
                .first(where: { $0.user.id == authentication.currentUser?.id })
        else {
            return nil
        }
        return currentParticipant.id
    }
    
    public var body: some View {
        ScrollViewReader { scrollView in
            ReversedScrollView(.vertical, showsIndicator: true) {
                LazyVStack(
                    alignment: .center,
                    spacing: -6,
                    pinnedViews: [.sectionHeaders, .sectionFooters]
                ) {
                    if let currentParticipantId = currentParticipantId {
                        ForEach(chatObserver.messages) { message in
                            MessageView(
                                currentParticipantId: currentParticipantId,
                                withTail: shouldHaveTail(message),
                                message: message
                            )
                        }
                        #if os(watchOS)
                        ChatInputBar(send: send)
                            .environmentObject(chatObserver)
                        #endif
                    } else {
                        Text("It seems that you are not a part of this chat!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .onAppear {
                    scrollToLastMessage(scrollProxy: scrollView)
                }
            }
            #if !os(watchOS)
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(send: send)
                    .environmentObject(chatObserver)
            }
            #endif
            .onChange(of: focused) { isFocused in
                if isFocused {
                    scrollToLastMessage(scrollProxy: scrollView)
                }
            }
            .onChange(of: chatObserver.messages.count) { _ in
                scrollToLastMessage(scrollProxy: scrollView)
            }
            #if os(iOS)
            .onReceive(keyboard.$height.debounce(for: 0.3, scheduler: RunLoop.main)) { _ in
                scrollToLastMessage(scrollProxy: scrollView)
            }
            #endif
            #if !os(watchOS) && !os(macOS)
            .toolbarTitleMenu {
                ForEach(chatObserver.participants) { participant in
                    HStack {
                        Circle().frame(width: 44, height: 44)
                        Text("@" + participant.user.username)
                    }
                }
                ShowNewParticipantsButton(showingNewParticipants: $showingNewParticipants)
            }
            .sheet(isPresented: $showingNewParticipants) {
                NewParticipantsView()
                    .environmentObject(chatObserver)
            }
            #endif
        }
        .navigationTitle(chatObserver.name)
        #if !os(watchOS) && !os(macOS)
        .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
        #endif
        .onAppear {
            // MARK: Connect to WebSocket
            if chatObserver.isConnected {
                return
            }
            do {
                try chatObserver.connect(chatId: chatObserver.chatId)
            } catch {
                print("Failed to connect:", error)
            }
        }
        .onDisappear {
            // MARK: Disconnect from WebSocket
            chatObserver.disconnect()
        }
        .toolbar {
            #if !os(watchOS) && !os(macOS)
            ToolbarTitleMenu()
            ToolbarItem {
                Button {
                    UIPasteboard.general.setValue(chatObserver.shareableUrl, forPasteboardType: UTType.url.identifier)
                    withAnimation {
                        presentedCopiedUrl = true
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            ToolbarItem {
                ShowNewParticipantsButton(showingNewParticipants: $showingNewParticipants)
            }
            #endif
        }
        #if !os(watchOS)
        .alert(isPresented: $presentedCopiedUrl) {
            Alert(title: Text("Link Copied!"), message: Text(""))
        }
        #endif
        .sheet(item: $presentedParticipant) {
            presentedParticipant = nil
        } content: { participant in
            if let presentedParticipant = presentedParticipant {
                ProfileView(user: presentedParticipant.user)
            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(ChatObserver(chat: Chat.GetResponse(id: UUID(), name: "Meow", salt: Data()), currentUserId: UUID()))
    }
}
