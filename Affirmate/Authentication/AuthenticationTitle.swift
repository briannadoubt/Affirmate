//
//  AuthenticationTitle.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AuthenticationTitle: View {
    @SceneStorage("auth.viewState") var viewState: AuthenticationObserver.ViewState = .signUp
    
    var body: some View {
        HStack {
            switch viewState {
            case .login:
                Text("Login")
                    .font(.largeTitle)
                    .bold()
            case .signUp:
                Text("Sign Up")
                    .font(.largeTitle)
                    .bold()
            }
            Spacer()
        }
    }
}

struct AuthenticationTitle_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationTitle()
    }
}
