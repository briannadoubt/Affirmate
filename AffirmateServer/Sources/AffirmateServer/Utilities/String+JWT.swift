//
//  String+JWT.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import JWT

extension String {
    var jwkIdentifier: JWKIdentifier {
        .init(string: self)
    }
}
