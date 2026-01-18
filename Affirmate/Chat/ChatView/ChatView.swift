//
//  ChatView.swift
//  Affirmate
//
//  Created by Bri on 8/18/22.
//

import AffirmateShared
import ReversedScrollView
import SwiftUI
import UniformTypeIdentifiers

public struct ChatView: View {
    
    @FetchRequest var messages: FetchedResults<Message>
    @FetchRequest var participants: FetchedResults<Participant>

    @Environment(AuthenticationObserver.self) private var authentication
    @Environment(ChatObserver.self) private var chatObserver
    
    @SceneStorage("chat_newMessageText") var newMessageText = ""
    @SceneStorage("chat_showingNewParticipants") var showingNewParticipants = false
    
    @State var presentedParticipant: ParticipantResponse?
    @State var presentedCopiedUrl = false
    
    #if os(iOS)
    @State private var keyboard = KeyboardHeightObserver()
    #endif
    
    @FocusState fileprivate var focused
    
    init(chatId: UUID) {
        _messages = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: NSPredicate(format: "chat.id == %@", chatId as CVarArg))
        _participants = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "role", ascending: true), NSSortDescriptor(key: "username", ascending: true)], predicate: NSPredicate(format: "chat.id == %@", chatId as CVarArg))
    }
    
    fileprivate func send() {
        Task {
            // Don't send if only whitespaces, or if message was empty
            guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            // TODO: Verify (with science) whether there are "not allowed" words in the message.
            do {
                try await chatObserver.sendMessage(newMessageText, to: Array(participants))
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
        if let message = messages.last {
            scrollToMessage(message.id, scrollProxy: scrollProxy)
        }
    }
    
    fileprivate func shouldHaveTail(_ message: Message) -> Bool {
        let messages = messages
        if let index = messages.firstIndex(of: message) {
            let nextMessageIndex = messages.index(after: index)
            if nextMessageIndex >= messages.count {
                return true
            }
            let nextMessage = messages[nextMessageIndex]
            if nextMessage.sender?.id != message.sender?.id {
                return true
            }
        }
        return false
    }
    
    var currentParticipantId: UUID? {
        guard
            let currentParticipant = participants.first(where: { $0.userId == authentication.currentUser?.id })
        else {
            return nil
        }
        return currentParticipant.id
    }
    
    public var body: some View {
        Group {
            scrollContent(sortedMessages: sortedMessages)
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
                Task {
                    do {
                        try await chatObserver.connect(chatId: chatObserver.chatId)
                    } catch WebSocketObserverError.socketUnavailable {
                        // The observer will retry once the task is ready.
                    } catch {
                        print("Failed to connect:", error)
                    }
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

    private var sortedMessages: [Message] {
        Array(messages)
    }

    private func scrollContent(sortedMessages: [Message]) -> some View {
        ScrollViewReader { scrollView in
            baseScroll(sortedMessages: sortedMessages, scrollView: scrollView)
            #if !os(watchOS)
            .safeAreaInset(edge: .bottom) {
                ChatInputBar(messages: sortedMessages, send: send)
                    .environment(chatObserver)
            }
            #endif
            .onChange(of: focused) { _, isFocused in
                if isFocused {
                    scrollToLastMessage(scrollProxy: scrollView)
                }
            }
            .onChange(of: messages.count) {
                scrollToLastMessage(scrollProxy: scrollView)
            }
            #if os(iOS)
            .onChange(of: keyboard.height) {
                scrollToLastMessage(scrollProxy: scrollView)
            }
            #endif
            #if !os(watchOS) && !os(macOS)
            .toolbarTitleMenu { participantsMenu }
            .sheet(isPresented: $showingNewParticipants) {
                NewParticipantsView(participants: Set(participants))
                    .environment(chatObserver)
            }
            #endif
            .task(id: messages.count) {
                scrollToLastMessage(scrollProxy: scrollView)
            }
        }
    }

    private func baseScroll(sortedMessages: [Message], scrollView: ScrollViewProxy) -> some View {
        ReversedScrollView(.vertical, showsIndicator: true) {
            messageStack(sortedMessages: sortedMessages, scrollView: scrollView)
        }
    }

    @ViewBuilder
    private var participantsMenu: some View {
        ForEach(participants) { participant in
            HStack {
                Circle().frame(width: 44, height: 44)
                Text("@" + (participant.username ?? ""))
            }
        }
        ShowNewParticipantsButton(showingNewParticipants: $showingNewParticipants)
    }

    @ViewBuilder
    private func messageStack(sortedMessages: [Message], scrollView: ScrollViewProxy) -> some View {
        LazyVStack(
            alignment: .center,
            spacing: -6,
            pinnedViews: [.sectionHeaders, .sectionFooters]
        ) {
            if let currentParticipantId = currentParticipantId {
                ForEach(sortedMessages, id: \.id) { (message: Message) in
                    MessageView(
                        currentParticipantId: currentParticipantId,
                        withTail: shouldHaveTail(message),
                        message: message
                    )
                }
                #if os(watchOS)
                ChatInputBar(messages: sortedMessages, send: send)
                    .environment(chatObserver)
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
}

// TODO: Fix preview
//struct ChatView_Previews: PreviewProvider {
//    static var previews: some View {
//        ChatView()
//            .environmentObject(ChatObserver(chat: Chat.GetResponse(id: UUID(), name: "Meow", salt: Data()), currentUserId: UUID()))
//    }
//}
