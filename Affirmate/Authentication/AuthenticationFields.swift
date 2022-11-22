//
//  AuthenticationFields.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AuthenticationFields: View {
    @SceneStorage("auth.viewState") var viewState: AuthenticationObserver.ViewState = .signUp
    
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var username: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    
    var showError: (_ error: Error) -> ()
    
    var body: some View {
        switch viewState {
        case .login:
            LoginView(username: $username, password: $password)
        case .signUp:
            SignUpView(firstName: $firstName, lastName: $lastName, email: $email, username: $username, password: $password, confirmPassword: $confirmPassword)
        }
    }
}

struct AuthenticationFields_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationFields(firstName: .constant("Meow"), lastName: .constant("Face"), username: .constant("meowface"), email: .constant("meow@fake.com"), password: .constant("Test123$"), confirmPassword: .constant("Test123$"), showError: { _ in })
    }
}
