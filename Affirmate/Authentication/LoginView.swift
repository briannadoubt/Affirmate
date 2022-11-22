//
//  LoginView.swift
//  Affirmate
//
//  Created by Bri on 10/13/22.
//

import SwiftUI

struct LoginView: View {
    @Binding var username: String
    @Binding var password: String
    
    var body: some View {
        Section {
            TextField("Username", text: $username)
                #if !os(macOS)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
            SecureField("Password", text: $password)
                .textContentType(.password)
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(username: .constant("meowface"), password: .constant("Test123$"))
    }
}
