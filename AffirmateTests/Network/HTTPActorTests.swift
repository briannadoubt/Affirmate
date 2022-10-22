//
//  HTTPActorTests.swift
//  AffirmateTests
//
//  Created by Bri on 10/22/22.
//

@testable import Affirmate
import Alamofire
import Foundation
import XCTest

final class HTTPActorTests: XCTestCase {
    
    var http: HTTPActor!
    
    var configuration: URLSessionConfiguration!
    var session: Session!

    override func setUpWithError() throws {
        configuration = URLSessionConfiguration.af.default
        configuration.protocolClasses = [MockURLProtocol.self] + (configuration.protocolClasses ?? [])
        session = Session(configuration: configuration)
        http = HTTPActor(session: session)
    }

    override func tearDownWithError() throws {
        configuration = nil
        session = nil
        http = nil
    }

    func test_decoder() async throws {
        let dateDecodingStrategy = await http.decoder.dateDecodingStrategy
        XCTAssertEqual(String(describing: dateDecodingStrategy), String(describing: JSONDecoder.DateDecodingStrategy.iso8601))
    }
    
    func test_request() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(TestRequest.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        try await http.request(TestRequest())
    }
    
    func test_request_whenStatusCodeIs401_shouldThrow_responseValidationFailed_and_logOut() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(TestRequest.url)
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }
        do {
            try await http.request(TestRequest())
        } catch let error as AFError {
            XCTAssertEqual("\(error)", "\(AFError.responseValidationFailed(reason: AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: 401)))")
        } catch {
            throw error
        }
        
    }
    
    func test_request_unauthorized() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(TestRequest.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        try await http.request(unauthorized: TestRequest())
    }
    
    func test_requestDecodable_whenStatusCodeIs401_shouldThrow_responseValidationFailed_and_logOut() async throws {
        let object = TestResponseObject(foo: "bar")
        MockURLProtocol.requestHandler = { request in
            let url = try XCTUnwrap(TestRequest.url)
            let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let data = try JSONEncoder().encode(object)
            return (response, data)
        }
        do {
            let responseObject = try await http.requestDecodable(TestRequest(), to: TestResponseObject.self)
        } catch let error as AFError {
            XCTAssertEqual("\(error)", "\(AFError.responseValidationFailed(reason: AFError.ResponseValidationFailureReason.unacceptableStatusCode(code: 401)))")
        } catch {
            throw error
        }
    }
}

struct TestResponseObject: Codable, Equatable {
    var foo: String
}

struct TestRequest: URLRequestConvertible {
    static var url = URL(string: "https://example.com/")!
    func asURLRequest() throws -> URLRequest {
        try URLRequest(url: Self.url, method: .get)
    }
}
