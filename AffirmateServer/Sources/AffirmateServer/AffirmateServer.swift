//
//  AffirmateServer.swift
//  AffirmateServer
//
//  Created by Bri on 8/29/22.
//

import Vapor

public class AffirmateServer: ObservableObject {
    
    var app: Application
    let port: Int
    
    public init(port: Int, environment: Environment) {
        self.port = port
        app = Application(environment)
        do {
            try configure(app)
        } catch {
            assertionFailure("Failed to configure app from GUI")
        }
    }
}
