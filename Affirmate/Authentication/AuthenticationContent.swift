//
//  AuthenticationContent.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AuthenticationContent: View {
    @EnvironmentObject var authentication: AuthenticationObserver
    
    #if DEBUG
    @State var firstName: String = "Meow"
    @State var lastName: String = "Face"
    @State var username: String = "meowface"
    @State var email: String = "meow@fake.com"
    @State var password: String = "Test123$"
    @State var confirmPassword: String = "Test123$"
    #else
    @State var firstName: String = ""
    @State var lastName: String = ""
    @State var username: String = ""
    @State var email: String = ""
    @State var password: String = ""
    @State var confirmPassword: String = ""
    #endif
    
    func showError(_ error: Error) {
        print("TODO: Display this error in the UI:", error)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            AuthenticationTitle()
            Divider()
            AuthenticationFields(firstName: $firstName, lastName: $lastName, username: $username, email: $email, password: $password, confirmPassword: $confirmPassword, showError: showError)
            AuthenticationConfirmationButtonSection(firstName: $firstName, lastName: $lastName, username: $username, email: $email, password: $password, confirmPassword: $confirmPassword, showError: showError)
            Divider()
            AuthenticationFlowSelectionSection()
        }
        .padding()
        .background {
            #if os(macOS)
            Color(.windowBackgroundColor).opacity(0.8)
            #elseif os(watchOS)
            Color.black.opacity(0.8)
            #else
            Color(.systemBackground).opacity(0.8)
                .backgroundStyle(.thinMaterial)
            #endif
        }
        .cornerRadius(16)
        .shadow(radius: 1)
    }
}

struct AuthenticationContent_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationContent()
    }
}
