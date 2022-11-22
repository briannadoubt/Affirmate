//
//  AuthenticationConfirmationButtonSection.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AuthenticationConfirmationButtonSection: View {
    @SceneStorage("auth.viewState") var viewState: AuthenticationObserver.ViewState = .signUp
    
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var username: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    
    var showError: (_ error: Error) -> ()
    
    var body: some View {
        Section {
            switch viewState {
            case .login:
                LoginButton(username: $username, password: $password, showError: showError)
            case .signUp:
                SignUpButton(firstName: $firstName, lastName: $lastName, username: $username, email: $email, password: $password, confirmPassword: $confirmPassword, showError: showError)
            }
        }
    }
}

struct AuthenticationConfirmationButtonSection_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationConfirmationButtonSection()
    }
}
