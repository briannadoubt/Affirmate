//
//  AffirmateSenderKeyName.swift
//  Affirmate
//
//  Created by Bri on 10/17/22.
//

import Foundation

/// A representation of a (group + sender + device) tuple
public struct AffirmateSenderKeyName {

    /// The group identifier (such as the name)
    let groupId: String

    /// The contact
    let sender: AffirmateAddress

    /**
     Create a new `SignalSenderKeyName`
     - parameter groupId: The group identifier (such as the name)
     - parameter sender: The contact
     */
    public init(groupId: String, sender: AffirmateAddress) {
        self.groupId = groupId
        self.sender = sender
    }
}

extension AffirmateSenderKeyName: Equatable {
    
    /**
     Compare two `AffirmateSenderKeyName`. Two `AffirmateSenderKeyName` objects are
     equal if their identifier and sender are equal.
     - parameter lhs: The first address
     - parameter rhs: The second address
     - returns: `True` if the addresses are equal.
     */
    public static func ==(lhs: AffirmateSenderKeyName, rhs: AffirmateSenderKeyName) -> Bool {
        return lhs.groupId == rhs.groupId && lhs.sender == rhs.sender
    }
}

extension AffirmateSenderKeyName: Hashable { }

extension AffirmateSenderKeyName: CustomStringConvertible {

    /**
     A String representation of the sender key name.
     */
    public var description: String {
        return "AffirmateSenderKeyName(group: \(groupId), id: \(sender.identifier), device: \(sender.deviceId))"
    }
}
