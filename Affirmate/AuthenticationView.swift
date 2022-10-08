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
                        TextField("Username", text: $username)
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
                            #if !os(watchOS)
                            Text("Need an account?")
                            #endif
                            Button("Sign up instead...") {
                                withAnimation {
                                    viewState = .signUp
                                }
                            }
                        case .signUp:
                            #if !os(watchOS)
                            Text("Already have an account?")
                            #endif
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
