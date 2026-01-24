//
//  SignalProtocol+Content.swift
//  AffirmateServer
//
//  Vapor Content conformance for Signal Protocol types from AffirmateShared.
//

import AffirmateShared
import Vapor

extension SignalPreKeyBundle: @retroactive Content {}
extension PreKeyCountResponse: @retroactive Content {}
extension SignalKeysUpload: @retroactive Content {}
extension SignedPreKeyUpload: @retroactive Content {}
extension OneTimePreKeyUpload: @retroactive Content {}
