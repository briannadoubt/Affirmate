//
//  MeView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct MeView: View {
    
    @EnvironmentObject var authentication: AuthenticationObserver
    
    func signOut() {
        Task {
            do {
                try await authentication.signOut()
            } catch {
                print("Failed to sign out:", error)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(role: .destructive, action: signOut) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right.fill")
                    }
                }
                if
                    let invitations = authentication.currentUser?.chatInvitations,
                    invitations.count > 0
                {
                    Section {
                        NavigationLink {
                            ChatInvitationsView(invitations: invitations)
                                .environmentObject(authentication)
                        } label: {
                            Label("Chat Invitations", systemImage: "\(authentication.currentUser?.chatInvitations.count ?? 0).circle.fill")
                        }
                    } header: {
                        Text("Chat Invitations")
                    }
                }
            }
            .navigationTitle(authentication.currentUser?.username ?? authentication.currentUser?.firstName ?? "Me")
            .task {
                do {
                    try await authentication.getCurrentUser()
                } catch {
                    print("Failed to get user:", error)
                }
            }
        }
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
