//
//  String+Fluent.swift
//  AffirmateServer
//
//  Created by Bri on 10/17/22.
//

import Fluent

extension String {
    var fieldKey: FieldKey { FieldKey(stringLiteral: self) }
}
