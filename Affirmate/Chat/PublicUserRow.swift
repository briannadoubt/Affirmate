//
//  PublicUserRow.swift
//  Affirmate
//
//  Created by Bri on 9/8/22.
//

import SwiftUI

struct PublicUserRow: View {
    let publicUser: AffirmateUser.Public
    var body: some View {
        HStack {
            Text("@") + Text(publicUser.username)
        }
    }
}

struct PublicUserRow_Previews: PreviewProvider {
    static var previews: some View {
        PublicUserRow(publicUser: AffirmateUser.Public(id: UUID(), username: "meowface"))
    }
}
