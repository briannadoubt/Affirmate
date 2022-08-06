//
//  AuthenticationRouteCollectionTests.swift
//  
//
//  Created by Bri on 8/2/22.
//

@testable import AffirmateServer
import XCTest
import XCTVapor

final class AuthenticationRouteCollectionTests: XCTestCase {

    var app: Application!
    
    override func setUpWithError() throws {
        self.app = Application(.testing)
        Task {
            try await configure(app)
        }
    }

    override func tearDown() {
        app.shutdown()
    }

    // MARK: /auth/new
    func test_newUser() async throws {
        let firstName = "Meow"
        let lastName = "Face"
        let username = "meowface"
        let email = "meow@fake.com"
        let password = "Test123$"
        let userCreate = User.Create(firstName: firstName, lastName: lastName, username: username, email: email, password: password, confirmPassword: password)
        try app.test(.POST, "/auth/new") { request in
            request.headers.contentType = .json
            try request.content.encode(userCreate)
        } afterResponse: { response in
            print(try JSONSerialization.jsonObject(with: response.body) as? [String: Any] ?? ["reason": "No error", "error": -1])
            let expectedGetResponse = User.GetResponse(firstName: firstName, lastName: lastName, username: username, email: email)
            let getResponse = try response.content.decode(User.GetResponse.self)
            XCTAssertEqual(getResponse, expectedGetResponse)
        }
    }
}
