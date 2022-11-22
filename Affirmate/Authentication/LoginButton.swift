//
//  LoginButton.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct LoginButton: View {
    @EnvironmentObject var authentication: AuthenticationObserver
    
    @Binding var username: String
    @Binding var password: String
    
    var showError: (_ error: Error) -> ()
    
    func login() {
        Task {
            do {
                try await authentication.login(username: username, password: password)
            } catch {
                showError(error)
            }
        }
    }
    
    var body: some View {
        Button(action: login) {
            ZStack {
                RoundedRectangle(cornerSize: .init(width: 8, height: 8))
                    .fill(Color.accentColor)
                Text("Login")
                    .padding(8)
                    .foregroundColor(.white)
            }
        }
    }
}

struct LoginButton_Previews: PreviewProvider {
    static var previews: some View {
        LoginButton(username: .constant("meowface"), password: .constant("Test123$"), showError: { _ in })
    }
}
