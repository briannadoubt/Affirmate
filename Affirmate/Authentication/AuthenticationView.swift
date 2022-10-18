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
        ZStack {
            GeometryReader { geometry in
                Image("rainbow")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    VStack(alignment: .center) {
                        Image("Affirmate")
                            .resizable()
                            .frame(width: 128, height: 128, alignment: .center)
                            .background {
                                Circle()
                                    .fill(.background.opacity(0.8))
                                    .backgroundStyle(.bar)
                            }
                            .shadow(radius: 1)
                        
                        VStack(spacing: 16) {
                            HStack {
                                switch viewState {
                                case .login:
                                    Text("Login")
                                        .font(.largeTitle)
                                        .bold()
                                case .signUp:
                                    Text("Sign Up")
                                        .font(.largeTitle)
                                        .bold()
                                }
                                Spacer()
                            }
                            
                            Divider()
                            
                            switch viewState {
                            case .login:
                                LoginView(username: $username, password: $password)
                            case .signUp:
                                SignUpView(firstName: $firstName, lastName: $lastName, email: $email, username: $username, password: $password, confirmPassword: $confirmPassword)
                            }
                            
                            Section {
                                switch viewState {
                                case .login:
                                    Button(action: login) {
                                        ZStack {
                                            RoundedRectangle(cornerSize: .init(width: 8, height: 8))
                                                .fill(Color.accentColor)
                                            Text("Login")
                                                .padding(8)
                                                .foregroundColor(.white)
                                        }
                                    }
                                        
                                case .signUp:
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
                            
                            Divider()
                            
                            Section {
                                let buttons = Group {
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
                                }
                                ViewThatFits {
                                    HStack {
                                        Spacer()
                                        buttons
                                        Spacer()
                                    }
                                    VStack {
                                        buttons
                                    }
                                }
                            }
                        }
                        .padding()
                        .background {
                            Color(.systemBackground).opacity(0.8)
                                .backgroundStyle(.thinMaterial)
                        }
                        .frame(minWidth: 300, idealWidth: 320, maxWidth: 600)
                        .cornerRadius(16)
                        .shadow(radius: 1)
                    }
                    .padding()
                }
                .onAppear {
                    try? authentication.authenticationActor.interceptor.removeTokens()
                }
                
                VStack {
                    Color.clear
                        .safeAreaInset(edge: .top) {
                            Color(.systemBackground)
                                .opacity(0.4)
                                .backgroundStyle(.bar)
                                .frame(height: geometry.safeAreaInsets.top)
                        }
                }
                .ignoresSafeArea()
            }
        }
    }
}

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
    }
}
