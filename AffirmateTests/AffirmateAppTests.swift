//
//  AffirmateAppTests.swift
//  AffirmateTests
//
//  Created by Bri on 7/1/22.
//

#if os(watchOS)
@testable import AffirmateWatch
#else
@testable import Affirmate
#endif
import XCTest

final class AffirmateAppTests: XCTestCase {

    func testIsFirstLaunch() throws {
        let app = AffirmateApp()
        XCTAssertTrue(app.isFirstLaunch)
    }

}
