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
    
    public init(token: String, organization: String? = nil) {
        self.serivce = .init(token: token,
                             organization: organization ?? "",
                             host: APIURL.openAI)
    }
    
    public init(serivce: Serivce) {
        self.serivce = serivce
    }
    
}

internal extension OpenAI {
    
    func makeRequest<R: Codable>(_ r: Request<R>) -> URLRequest? {
        var url = URL(string: serivce.host.isEmpty ? APIURL.openAI : serivce.host)
        url?.appendPathComponent(r.url.value)
        
        guard let url = url else {
            return nil
        }
        
        var request = URLRequest(url: url, timeoutInterval: r.timeoutInterval)
        request.httpMethod = r.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !serivce.token.isEmpty {
            request.setValue("Bearer \(serivce.token)", forHTTPHeaderField: "Authorization")
        }
        if !serivce.organization.isEmpty {
            request.setValue(serivce.organization, forHTTPHeaderField: "OpenAI-Organization")
        }
        if let query = r.body, let body = try? JSONEncoder().encode(query)  {
            request.httpBody = body
        }
        return request
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
        
        let value: String
        
        static let models      = APIPath(value: "v1/models")
        static let completions = APIPath(value: "v1/completions")
        static let images      = APIPath(value: "v1/images/generations")
        static let embeddings  = APIPath(value: "v1/embeddings")
        static let chats       = APIPath(value: "v1/chat/completions")
        
    }
    
}
