//
//  NewParticipantPublicUserRow.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import AffirmateShared
import SwiftUI

struct NewParticipantPublicUserRow: View {
    let publicUser: UserPublic
    var body: some View {
        HStack {
            Text("@") + Text(publicUser.username)
        }
    }
}

struct NewParticipantPublicUserRow_Previews: PreviewProvider {
    static var previews: some View {
        NewParticipantPublicUserRow(publicUser: UserPublic(id: UUID(), username: "meowface"))
    }
}
