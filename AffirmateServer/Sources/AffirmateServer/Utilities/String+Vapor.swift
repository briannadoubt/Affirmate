//
//  String+Vapor.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Vapor

extension String {
    var validationKey: ValidationKey { ValidationKey(stringLiteral: self) }
}
