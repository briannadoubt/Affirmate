//
//  APNSDeviceToken.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

struct APNSDeviceToken: Content {
    var token: Data?
}
