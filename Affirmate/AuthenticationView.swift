//
//  AuthenticationView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct AuthenticationView: View {
    
    @EnvironmentObject var authentication: Authentication
    
    @SceneStorage("auth.viewState") var viewState: Authentication.ViewState = .signUp
    
    #if DEVELOPMENT
    @SceneStorage("auth.first_name") var firstName: String = "Meow"
    @SceneStorage("auth.last_name") var lastName: String = "Face"
    @SceneStorage("auth.username") var username: String = "meowface"
    @SceneStorage("auth.email") var email: String = "meow@fake.com"
    @State var password: String = "Test123$"
    @State var confirmPassword: String = "Test123$"
    #else
    @SceneStorage("auth.first_name") var firstName: String = ""
    @SceneStorage("auth.last_name") var lastName: String = ""
    @SceneStorage("auth.username") var username: String = ""
    @SceneStorage("auth.email") var email: String = ""
    @State var password: String = ""
    @State var confirmPassword: String = ""
    #endif
    
    @MainActor func showError(_ error: Error) {
        print("TODO: Display this error in the UI:", error)
    }
    
    func login() {
        Task {
            do {
                try await authentication.login(username: username, password: password)
            } catch {
                authentication.state = .loggedOut
                showError(error)
            }
        }
    }
    
    func signUp() {
        Task {
            do {
                let newUser = User.Create(
                    firstName: firstName,
                    lastName: lastName,
                    username: username,
                    email: email,
                    password: password,
                    confirmPassword: confirmPassword
                )
                try await authentication.signUp(userCreate: newUser)
                try await authentication.login(username: email, password: password)
            } catch {
                authentication.state = .loggedOut
                showError(error)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            let rainbowImage = Image("rainbow")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            #if os(macOS)
            rainbowImage
            #endif
            Form {
                Picker("Authentication Mode", selection: $viewState.animation(.spring())) {
                    ForEach(Authentication.ViewState.allCases.reversed()) { viewState in
                        Text(viewState.labelText)
                            .tag(viewState)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                switch viewState {
                case .login:
                    Section {
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                    } header: {
                        Text("Login")
                    }
                case .signUp:
                    Section {
                        TextField("First Name", text: $firstName)
                            .textContentType(.givenName)
                        TextField("Last Name", text: $lastName)
                            .textContentType(.familyName)
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Username", text: $username)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                        SecureField("New Password", text: $password)
                            .textContentType(.newPassword)
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)
                    } header: {
                        Text("Sign Up")
                    }
                }
                Section {
                    switch viewState {
                    case .login:
                        Button("Login", action: login)
                    case .signUp:
                        Button("Sign Up", action: signUp)
                    }
                }
            }
            .onAppear {
                do {
                    try HTTPActor.Interceptor.removeTokens()
                } catch {
                    print("TODO: Display error on screen:", error.localizedDescription)
                }
            }
            .navigationTitle("Authentication")
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
