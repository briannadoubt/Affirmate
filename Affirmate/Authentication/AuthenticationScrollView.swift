//
//  AuthenticationScrollView.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import AffirmateShared
import SwiftUI

struct AuthenticationScrollView: View {
    #if os(watchOS)
    let vertices: Axis.Set = .vertical
    #else
    let vertices: Axis.Set = [.vertical, .horizontal]
    #endif
    
    var body: some View {
        ScrollView(vertices, showsIndicators: false) {
            VStack(alignment: .center) {
                AffirmateLogo()
                AuthenticationContent()
            }
            .padding()
        }
        .onAppear {
            try? AffirmateKeychain.session.remove(Constants.KeyChain.Session.token)
        }
    }
}

struct AuthenticationScrollView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationScrollView()
    }
}
