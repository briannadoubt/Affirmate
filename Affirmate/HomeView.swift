//
//  HomeView.swift
//  Affirmate
//
//  Created by Bri on 7/31/22.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        #if os(macOS)
        NavigationView {
            List {
                Text("The place for things")
            }
            .navigationTitle("Affirmate")
            
            List {
                Text("This is the home page")
            }
            .navigationTitle("Home")
        }
        #else
        NavigationSplitView {
            List {
                Text("The place for things")
            }
            .navigationTitle("Affirmate")
        } detail: {
            List {
                Text("This is the home page")
            }
            .navigationTitle("Home")
        }
        #endif
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
