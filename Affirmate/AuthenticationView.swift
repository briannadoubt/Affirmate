//
//  AuthenticationView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct AuthenticationView: View {
    
    @EnvironmentObject var authentication: AuthenticationObserver
    
    @SceneStorage("auth.viewState") var viewState: AuthenticationObserver.ViewState = .signUp
    
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
                showError(error)
            }
        }
    }
    
    func signUp() {
        Task {
            do {
                let newUser = AffirmateUser.Create(
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
        NavigationView {
            let rainbowImage = Image("rainbow")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            #if os(macOS)
            rainbowImage
//            #elseif os(iOS)
//            if UIScreen.main.traitCollection.horizontalSizeClass == .regular {
//                rainbowImage
//            }
            #endif
            Form {
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
                
                Section {
                    HStack {
                        Spacer()
                        switch viewState {
                        case .login:
                            Text("Need an account?")
                            Button("Sign up instead...") {
                                withAnimation {
                                    viewState = .signUp
                                }
                            }
                        case .signUp:
                            Text("Already have an account?")
                            Button("Login instead...") {
                                withAnimation {
                                    viewState = .login
                                }
                            }
                        }
                        Spacer()
                    }
                    .font(.caption)
                    .listRowBackground(Color.clear)
                }
            }
            .onAppear {
                try? authentication.authenticationActor.interceptor.removeTokens()
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
