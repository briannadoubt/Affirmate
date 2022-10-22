//
//  AffirmateAppTests.swift
//  AffirmateTests
//
//  Created by Bri on 7/1/22.
//

@testable import Affirmate
import XCTest

final class AffirmateAppTests: XCTestCase {

    func testIsFirstLaunch() throws {
        let app = AffirmateApp()
        XCTAssertTrue(app.isFirstLaunch)
    }

}
