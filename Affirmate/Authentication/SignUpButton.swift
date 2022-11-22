//
//  SignUpButton.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import AffirmateShared
import SwiftUI

struct SignUpButton: View {
    @EnvironmentObject var authentication: AuthenticationObserver
    
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var username: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    
    var showError: (_ error: Error) -> ()
    
    func signUp() {
        Task {
            do {
                let newUser = UserCreate(
                    firstName: firstName,
                    lastName: lastName,
                    username: username,
                    email: email,
                    password: password,
                    confirmPassword: confirmPassword
                )
                print("Signing up new user")
                try await authentication.signUp(user: newUser)
            } catch {
                showError(error)
            }
        }
    }
    
    var body: some View {
        Button(action: signUp) {
            ZStack {
                RoundedRectangle(cornerSize: .init(width: 8, height: 8))
                    .fill(Color.accentColor)
                Text("Sign Up")
                    .padding(8)
                    .foregroundColor(.white)
            }
        }
    }
}

struct SignUpButton_Previews: PreviewProvider {
    static var previews: some View {
        SignUpButton(firstName: .constant("Meow"), lastName: .constant("Face"), username: .constant("meowface"), email: .constant("meow@fake.com"), password: .constant("Test123$"), confirmPassword: .constant("Test123$"), showError: { _ in })
    }
}
