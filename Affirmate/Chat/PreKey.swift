//
//  PreKey.swift
//  Affirmate
//
//  Created by Bri on 10/16/22.
//

import Foundation

struct PreKey: Object {
    var id: UUID
    var data: Data
    var invitation: ChatInvitation?
}
