//
//  AuthenticationActorTests.swift
//  AffirmateTests
//
//  Created by Bri on 11/22/22.
//

@testable import Affirmate
import AffirmateShared
import Alamofire
import KeychainAccess
import XCTest

final class AuthenticationActorTests: XCTestCase {

    var actor: AuthenticationActor!
    var http: MockHTTPActor!
    var keychain: Keychain!
    
    static let userId = UUID()
    static let firstName = "Meow"
    static let lastName = "Face"
    static let username = "meowface"
    static let email = "meow@fake.com"
    static let password = "Test123$"
    static let confirmPassword = "Test123$"
    
    var userCreate: UserCreate {
        UserCreate(firstName: Self.firstName, lastName: Self.lastName, username: Self.username, email: Self.email, password: Self.password, confirmPassword: Self.confirmPassword)
    }
    
    override func setUpWithError() throws {
        keychain = Keychain()
        http = MockHTTPActor(keychain: keychain)
        actor = AuthenticationActor(http: http)
    }

    override func tearDownWithError() throws {
        actor = nil
        http = nil
        keychain = nil
    }

    func test_signUp() async throws {
        try await actor.signUp(user: userCreate)
        let called_request_unauthorized = await http.called_request_unauthorized
        XCTAssertEqual(called_request_unauthorized, 1)
    }
    
    func test_signUp_httpActorFailed() async throws {
        await http.set(shouldFail: true)
        do {
            try await actor.signUp(user: userCreate)
            XCTFail("Call should fail.")
        } catch {
            let error = try XCTUnwrap(error as? MockError)
            XCTAssertEqual(error, .youToldMeTo)
            let called_request_unauthorized = await http.called_request_unauthorized
            XCTAssertEqual(called_request_unauthorized, 1)
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
