//
//  ContentView.swift
//  AffirmateServerGUI
//
//  Created by Bri on 8/29/22.
//

import SwiftUI
import AffirmateServer

struct ContentView: View {
    @StateObject var server = AffirmateServer(port: 8080)
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Button("Start Server") {
                
            }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
