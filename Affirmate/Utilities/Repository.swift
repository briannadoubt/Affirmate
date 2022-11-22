//
//  Repository.swift
//  Affirmate
//
//  Created by Bri on 7/1/22.
//

import Foundation
import Alamofire

protocol Repository { }

extension Repository {
    var http: HTTPActor {
        HTTPActor()
    }
    var interceptor: HTTPActor.Interceptor {
        http.interceptor
    }
}
