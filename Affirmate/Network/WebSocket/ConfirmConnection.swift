//
//  ConfirmConnection.swift
//  Affirmate
//
//  Created by Bri on 8/23/22.
//

import Foundation

/// An object used to confirm whether or not a connection was established.
struct ConfirmConnection: Codable {
    /// Whether or not the connection was established.
    var connected: Bool
}
