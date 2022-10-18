//
//  SignUpView.swift
//  Affirmate
//
//  Created by Bri on 10/13/22.
//

import SwiftUI

struct SignUpView: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var email: String
    @Binding var username: String
    @Binding var password: String
    @Binding var confirmPassword: String
    var body: some View {
        Section {
            TextField("First Name", text: $firstName)
                #if !os(macOS)
                .textContentType(.givenName)
                #endif
            TextField("Last Name", text: $lastName)
                #if !os(macOS)
                .textContentType(.familyName)
                #endif
            TextField("Email", text: $email)
                #if !os(macOS)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
            TextField("Username", text: $username)
                .textContentType(.username)
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                #endif
            SecureField("New Password", text: $password)
                #if os(macOS)
                .textContentType(.password)
                #else
                .textContentType(.newPassword)
                #endif
            SecureField("Confirm Password", text: $confirmPassword)
                #if os(macOS)
                .textContentType(.password)
                #else
                .textContentType(.newPassword)
                #endif
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(
            firstName: .constant("Meow"),
            lastName: .constant("Face"),
            email: .constant("meow@fake.com"),
            username: .constant("meowface"),
            password: .constant("Test123$"),
            confirmPassword: .constant("Test123$")
        )
    }
}
