//
//  Application+Testable.swift
//  AffirmateServerTests
//
//  Created by Bri on 8/6/22.
//

@testable import XCTVapor
@testable import AffirmateServer

extension Application {
    static func testable() throws -> Application {
        let app = Application(.testing)
        defer { app.tearDown() }
        try configure(app)
        return app
    }
    
    func tearDown() {
        self.shutdown()
    }
}

extension XCTApplicationTester {
    
    public func login(user: User) throws -> SessionToken {
        var request = XCTHTTPRequest(
            method: .POST,
            url: .init(path: "/auth/login"),
            headers: [:],
            body: ByteBufferAllocator().buffer(capacity: 0)
        )
        request.headers.basicAuthorization = .init(username: user.username, password: "password")
        let response = try performTest(request: request)
        return try response.content.decode(SessionToken.self)
    }

//    @discardableResult
//    public func test(
//        _ method: HTTPMethod,
//        _ path: String,
//        headers: HTTPHeaders = [:],
//        body: ByteBuffer? = nil,
//        loggedInRequest: Bool = false,
//        loggedInUser: User? = nil,
//        file: StaticString = #file,
//        line: UInt = #line,
//        beforeRequest: (inout XCTHTTPRequest) throws -> () = { _ in },
//        afterResponse: (XCTHTTPResponse) throws -> () = { _ in }
//    ) throws -> XCTApplicationTester {
//        var request = XCTHTTPRequest(
//            method: method,
//            url: .init(path: path),
//            headers: headers,
//            body: body ?? ByteBufferAllocator().buffer(capacity: 0)
//        )
//
//        if (loggedInRequest || loggedInUser != nil) {
//            let userToLogin: User
//            if let user = loggedInUser {
//                userToLogin = user
//            } else {
//                userToLogin = User(firstName: "Meow", lastName: "Face", username: "mewoface", email: "meowface@fake.com", passwordHash: try Bcrypt.hash("Test123$"))
//            }
//
//            let token = try login(user: userToLogin)
//            request.headers.bearerAuthorization = .init(token: token.value)
//        }
//
//        try beforeRequest(&request)
//
//        do {
//            let response = try performTest(request: request)
//            try afterResponse(response)
//        } catch {
//            XCTFail("\(error)", file: (file), line: line)
//            throw error
//        }
//        return self
//    }
}
