//
//  MeView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct MeView: View {
    @EnvironmentObject var authentication: Authentication
    func signOut() {
        Task {
            do {
                try await authentication.signOut()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    var body: some View {
        List {
            Section {
                Button(role: .destructive, action: signOut) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right.fill")
                }
            }
        }
        .navigationTitle("Me")
    }
}

struct MeView_Previews: PreviewProvider {
    static var previews: some View {
        MeView()
    }
}
