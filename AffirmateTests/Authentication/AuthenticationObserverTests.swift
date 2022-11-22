//
//  AuthenticationObserverTests.swift
//  AffirmateTests
//
//  Created by Bri on 11/20/22.
//

@testable import Affirmate
import XCTest

final class AuthenticationObserverTests: XCTestCase {

    var observer: AuthenticationObserver!
    var meActor: MockUserActor!
    var authenticationActor: MockAuthenticationActor!
    
    override func setUpWithError() throws {
        meActor = MockUserActor()
        authenticationActor = MockAuthenticationActor()
        observer = AuthenticationObserver()
    }

    override func tearDownWithError() throws {
        observer = nil
        authenticationActor = nil
        meActor = nil
    }

    func test_getCurrentUser() async throws {
        try await observer.getCurrentUser()
        let calledMe = await meActor.called_me
        XCTAssertEqual(calledMe, 1)
        XCT
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
