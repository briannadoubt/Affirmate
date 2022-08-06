//
//  AffirmateApp.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import SwiftUI

struct ServerError: Decodable {
    var error: String?
    var reason: String?
}

@main
struct AffirmateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
