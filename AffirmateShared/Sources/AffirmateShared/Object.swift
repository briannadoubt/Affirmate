//
//  Object.swift
//  AffirmateShared
//
//  Created by Bri on 11/21/22.
//

import Foundation
import _Concurrency

protocol Object: Codable, Equatable, Hashable, Sendable { }

protocol IdentifiableObject: Object, Identifiable { }
