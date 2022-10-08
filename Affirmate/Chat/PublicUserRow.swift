//
//  NewParticipantPublicUserRow.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct NewParticipantPublicUserRow: View {
    let publicUser: AffirmateUser.Public
    var body: some View {
        HStack {
            Text("@") + Text(publicUser.username)
        }
    }
}

struct NewParticipantPublicUserRow_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantPublicUserRow(publicUser: AffirmateUser.Public(id: UUID(), username: "meowface"))
    }
}
