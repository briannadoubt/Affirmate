//
//  PopulateChatsList.swift
//  Affirmate
//
//  Created by Bri on 10/8/22.
//

import SwiftUI

extension View {
    func populateChatsList(_ getChats: @escaping () async -> ()) -> some View {
        modifier(PopulateChatsList(getChats: getChats))
    }
}

struct PopulateChatsList: ViewModifier {
    var getChats: () async -> ()
    func body(content: Content) -> some View {
        content
            .refreshable {
                await getChats()
            }
            .task {
                await getChats()
            }
            .navigationTitle("Chat")
#if !os(watchOS)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NewChatButton()
                }
            }
#endif
    }
}

struct PopulateChatsList_Previews: PreviewProvider {
    static var previews: some View {
        List { }
            .populateChatsList { }
    }
}
