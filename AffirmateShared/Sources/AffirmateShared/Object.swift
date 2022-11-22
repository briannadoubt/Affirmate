//
//  Object.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation

protocol Object: Codable, Equatable, Hashable { }

protocol IdentifiableObject: Object, Identifiable { }
