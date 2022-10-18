//
//  AffirmateAddress.swift
//  Affirmate
//
//  Created by Bri on 10/17/22.
//

import Foundation


/// An `AffirmateAddress` identifies a single device of an Affirmate user, with a user `identifier` (such as the user's uid), and the `deviceId` which specifies the device.
public struct AffirmateAddress {

    /// The unique identifier of a user (such as the user's uid).
    public let identifier: UUID

    /// The identifier for the individual device of a user.
    public let deviceId: UInt32

    /**
     
     - parameter identifier: The user identifier (such as phone number)
     - parameter deviceId: The id of the user's device
     */
    
    
    /// Create an `AffirmateAddress`.
    /// - Parameters:
    ///   - identifier: The unique identifier of a user (such as the user's uid).
    ///   - deviceId: The id of the user's device
    public init(identifier: UUID, deviceId: UInt32) {
        self.identifier = identifier
        self.deviceId = deviceId
    }
}

extension AffirmateAddress: Equatable {

    /**
     Compare two AffirmateAddresses. Two `AffirmateAddress` objects are
     equal if both their identifier and deviceId are equal.
     - parameter lhs: The first address
     - parameter rhs: The second address
     - returns: `True` if the addresses are equal.
    */
    public static func ==(lhs: AffirmateAddress, rhs: AffirmateAddress) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.deviceId == rhs.deviceId
    }
}

extension AffirmateAddress: Hashable { }

extension AffirmateAddress: CustomStringConvertible {

    /**
     A description of the AffirmateAddress.
     */
    public var description: String {
        return "AffirmateAddress(\(identifier),\(deviceId))"
    }
}
