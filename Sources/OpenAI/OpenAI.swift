//
//  OpenAI.swift
//  Oasis
//
//  Created by Sergii Kryvoblotskyi on 9/18/22.
//

import Foundation
import Alamofire
import Combine

final public class OpenAI {
    
    public struct Serivce: Codable, Equatable {
        
        public var token: String
        public var organization: String
        public var host: String
        
        public init(token: String, organization: String, host: String) {
            self.token = token
            self.organization = organization
            self.host = host
        }
        
        public static let none = Serivce(token: "", organization: "", host: "")
    }
    
    public let serivce: Serivce
    private let session = URLSession.shared
    
    var eventSources = Set<EventSource>()
    var cancellables = Set<AnyCancellable>()
    
    public init(token: String, organization: String? = nil) {
        self.serivce = .init(token: token,
                             organization: organization ?? "",
                             host: APIURL.openAI)
    }
    
    public init(serivce: Serivce) {
        self.serivce = serivce
    }
    
}

public extension OpenAI {
    
    func uri(_ path: OpenAI.APIPath) -> String {
        var uri = serivce.host.isEmpty ? APIURL.openAI : serivce.host
        if uri.hasSuffix("/") {
            uri.append(path.value)
        } else {
            uri.append("/")
            uri.append(path.value)
        }
        return uri
    }
    
    func headers() -> [String: String] {
        var headers = [String: String]()
        headers["Content-Type"]  = "application/json"
        if !serivce.token.isEmpty {
            headers["Authorization"] = "Bearer \(serivce.token)"
        }
        if !serivce.organization.isEmpty {
            headers["OpenAI-Organization"]  = serivce.organization
        }
        return headers
    }
    
    func request(body: Codable?,
                 path: OpenAI.APIPath,
                 method: HTTPMethod,
                 timeoutInterval: TimeInterval = 60) -> URLRequest? {
        guard let url = URL(string: uri(path)) else {
            return nil
        }
        
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = method.rawValue
        headers().forEach { (key, value) in
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let query = body, let body = try? JSONEncoder().encode(query)  {
            request.httpBody = body
        }
        return request
    }
    
}

extension OpenAI {

    func makeRequest<R: Codable>(_ r: Request<R>) -> URLRequest? {
        return request(body: r.body, path: r.url, method: r.method, timeoutInterval: r.timeoutInterval)
    }
    
    func performRequest<ResultType: Codable>(request: Request<ResultType>) -> AnyPublisher<ResultType, Error> {
        
        guard let request = makeRequest(request) else {
            return Fail<ResultType, OpenAIError>(error: OpenAIError.invalidURL)
                .mapError({ $0 })
                .eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<ResultType, Error>()
        AF.request(request)
            .validate(statusCode: 200...299)
            .responseData { response in
                switch response.result {
                case .failure(let error):
                    subject.send(completion: .failure(error))
                case .success(let value):
                    do {
                        let type = try JSONDecoder().decode(ResultType.self, from: value)
                        subject.send(type)
                    } catch {
                        subject.send(completion: .failure(error))
                    }
                }
            }
        
        return subject.eraseToAnyPublisher()
    }
    
    
}

public extension OpenAI {
    
     struct APIURL {
        
        public static let openAI = "https://api.openai.com"
        
    }
    
     struct APIPath {
        
        public let value: String
        
        public static let models      = APIPath(value: "v1/models")
        public static let completions = APIPath(value: "v1/completions")
        public static let images      = APIPath(value: "v1/images/generations")
        public static let embeddings  = APIPath(value: "v1/embeddings")
        public static let chats       = APIPath(value: "v1/chat/completions")
        
    }
    
}
