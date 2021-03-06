//
//  Webservice.swift
//  Copyright © 2017 VoIPGRID. All rights reserved.
//

import Foundation

enum WebserviceError: Error {
    case unauthorized
    case forbidden
    case notFound
    case other(String)
}

enum Result<A> {
    case success(A)
    case failure(Error)
}

final class Webservice {
    private let basicAuth: String

    /// Default initializer
    ///
    /// Will setup the basic authentication for each request
    ///
    /// - Parameters:
    ///   - username: String with username for authentication
    ///   - password: String with password for authentication
    init(username: String, password: String) {
        basicAuth = "\(username):\(password)".data(using: String.Encoding.utf8)!.base64EncodedString()
    }

    /// Fires request to remote service
    ///
    /// - Parameters:
    ///   - resource: The resource that is requested
    ///   - completion: completionblock that will be called after the request has finished.
    ///         Completionblock will be called with WebserviceResult
    func load<A>(resource: Resource<A>, completion: @escaping (Result<A?>) -> ()) {
        let request = URLRequest(resource: resource, basicAuth: basicAuth)
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                completion(.failure(error!))
                return
            }

            let resp = response as! HTTPURLResponse
            switch resp.statusCode {
            case 401:
                NotificationCenter.default.post(name: NSNotification.Name.VoIPGRIDRequestOperationManagerUnAuthorized, object: nil)
                completion(.failure(WebserviceError.unauthorized))
            case 403:
                completion(.failure(WebserviceError.forbidden))
            case 404:
                completion(.failure(WebserviceError.notFound))
            case let code where code / 100 != 2:
                completion(.failure(WebserviceError.other("Wrong status: \(resp.statusCode)")))
            default:
                let result = data.flatMap(resource.parse)
                completion(.success(result))
            }
        }.resume()
    }
}
