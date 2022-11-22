//
//  AuthenticationFlowSelectionSection.swift
//  Affirmate
//
//  Created by Bri on 11/22/22.
//

import SwiftUI

struct AuthenticationFlowSelectionSection: View {
    @SceneStorage("auth.viewState") var viewState: AuthenticationObserver.ViewState = .signUp
    
    var body: some View {
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
            #if os(macOS)
            HStack {
                Spacer()
                buttons
                Spacer()
            }
            #else
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
            #endif
        }
    }
}

struct AuthenticationFlowSelectionSection_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationFlowSelectionSection()
    }
}
