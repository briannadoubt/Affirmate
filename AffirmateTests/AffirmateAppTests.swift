//
//  AffirmateAppTests.swift
//  AffirmateTests
//
//  Created by Bri on 7/1/22.
//

@testable import Affirmate
import XCTest

final class AffirmateAppTests: XCTestCase {

    
    
    override func setUpWithError() throws {
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    #if os(macOS)
    func testIsFirstLaunch() throws {
        let app = AffirmateApp()
        XCTAssertTrue(app.isFirstLaunch)
    }
    #endif

}
