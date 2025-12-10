//
//  Log.swift
//  Affirmate
//
//  Created by Bri on 10/13/22.
//

import Foundation
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "org.affirmate"

    /// Logs the view cycle.
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")

    /// Logs the network traffic
    static let network = Logger(subsystem: subsystem, category: "network")
}
