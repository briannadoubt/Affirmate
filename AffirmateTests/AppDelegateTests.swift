//
//  AppDelegateTests.swift
//  AffirmateTests
//
//  Created by Bri on 10/21/22.
//

@testable import Affirmate
import XCTest

final class AppDelegateTests: XCTestCase {

    func test_deviceToken_isNilOnLaunch() throws {
        XCTAssertNil(AppDelegate.deviceToken)
    }

}
