//
//  ShowNewParticipantsButton.swift
//  Affirmate
//
//  Created by Bri on 9/10/22.
//

import SwiftUI

struct ShowNewParticipantsButton: View {
    @Binding var showingNewParticipants: Bool
    var body: some View {
        Button {
            showingNewParticipants = true
        } label: {
            Label("New Participant", systemImage: "plus.message")
        }
    }
}

struct ShowNewParticipantsButton_Previews: PreviewProvider {
    static var previews: some View {
        ShowNewParticipantsButton(showingNewParticipants: .constant(true))
    }
}
