//
//  ChatsView.swift
//  DistributedChat
//
//  Created by Bri on 7/21/22.
//

import SwiftUI

final class ChatsObserver: ObservableObject {
    @Published var chats: [Chat.GetResponse] = []
    func getChats() async throws {
        
    }
}

struct ChatsView: View {
    
    @StateObject var observer = ChatsObserver()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(observer.chats, id: \.chat.id) { chat in
                    ChatNavigationLink(chat: chat)
                }
            }
            .navigationTitle("Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation {
                            
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct ChatsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatsView(observer: ChatsObserver())
    }
}
