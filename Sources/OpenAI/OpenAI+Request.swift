//
//  File.swift
//  
//
//  Created by linhey on 2023/5/19.
//

import Foundation
import Combine
import Alamofire
import OpenAICore

public extension OpenAI {
    
    func request(body: Codable?, path: OAIPath, method: HTTPMethod, timeoutInterval: TimeInterval = 60) -> URLRequest? {
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
    
    func makeRequest<R: Codable>(_ r: Request<R>) -> URLRequest? {
        return request(body: r.body, path: r.url, method: r.method, timeoutInterval: r.timeoutInterval)
    }
    
    func performRequest<ResultType: Codable>(request: Request<ResultType>) -> AnyPublisher<ResultType, Error> {
        
        guard let request = makeRequest(request) else {
            return Fail<ResultType, OAIError>(error: OAIError.invalidURL)
                .mapError({ $0 })
                .eraseToAnyPublisher()
        }
        
        let subject = PassthroughSubject<ResultType, Error>()
        AF.request(request)
            .validate(statusCode: 200...299)
            .responseData { response in
                switch response.result {
                case .failure(let error):
                    if let data = response.data {
                        if let response = try? JSONDecoder().decode(OAIErrorResponse.self, from: data) {
                            subject.send(completion: .failure(response.error))
                        } else if let text = String(data: data, encoding: .utf8) {
                            subject.send(completion: .failure(OAIError(message: text)))
                        } else {
                            subject.send(completion: .failure(error))
                        }
                    } else {
                        subject.send(completion: .failure(error))
                    }
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
    
    struct ChatStreamItem {
        public let chat: Chat
        public let stream: DataStreamRequest.Stream<Data, Never>?
    }
    
    func chats(query: ChatQuery) -> AnyPublisher<ChatResult, Error> {
        performRequest(request: Request<ChatResult>(body: query, url: .chats))
    }
    
    func chats(query: ChatQuery, interval: TimeInterval? = nil) -> AsyncThrowingStream<ChatStreamItem, Error> {
        .init { continuation in
            if let stream = query.stream, stream {
                var date = Date()
                chats(query: query, timeoutInterval: 60) { result in
                    let now = Date()
                    if let interval = interval, now.timeIntervalSince(date) >= interval {
                        continuation.yield(result)
                        date = now
                    }
                } completion: { result in
                    switch result {
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    case .success(let value):
                        if let chat = value.choices.first?.message {
                            continuation.yield(.init(chat: chat, stream: nil))
                        }
                        continuation.finish()
                    }
                }
            } else {
                chats(query: query).sink { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.finish(throwing: error)
                    }
                } receiveValue: { result in
                    continuation.yield(.init(chat: result.chat, stream: nil))
                }.store(in: &cancellables)
            }
        }
    }
    
    func chats(query: ChatQuery, timeoutInterval: TimeInterval = 60.0) -> AnyPublisher<ChatStreamItem, Error> {
        let suject = PassthroughSubject<ChatStreamItem, Error>()
        chats(query: query, timeoutInterval: timeoutInterval) { result in
            suject.send(result)
        } completion: { result in
            switch result {
            case .failure(let error):
                suject.send(completion: .failure(error))
            case .success(let value):
                if let chat = value.choices.first?.message {
                    suject.send(.init(chat: chat, stream: nil))
                }
                suject.send(completion: .finished)
            }
        }
        return suject.eraseToAnyPublisher()
    }
    
    func chats(query: ChatQuery,
               timeoutInterval: TimeInterval = 60.0,
               stream: @escaping (_ stream: ChatStreamItem) -> Void,
               completion: @escaping (Result<ChatResult, Error>) -> Void) {
        var query = query
        query.stream = true
        guard let request = makeRequest(Request<ChatQuery>(body: query, url: .chats, timeoutInterval: timeoutInterval)) else {
            completion(.failure(OAIError.invalidURL))
            return
        }
        
        let decoder = JSONDecoder()
        var blocks = [OpenAI.DeltaChatResult]()
        var chat = Chat(role: .assistant, content: "")
        let parser = EventStreamParser()
        AF.streamRequest(request).responseStream { response in
            switch response.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    if let response = try? decoder.decode(OAIErrorResponse.self, from: data) {
                        completion(.failure(response.error))
                    } else {
                        let list = parser.append(data: data)
                            .compactMap({ $0.data(using: .utf8) })
                            .compactMap({ try? decoder.decode(OpenAI.DeltaChatResult.self, from: $0) })
                        blocks.append(contentsOf: list)
                        chat.content += list.compactMap(\.choices.first?.delta?.content).joined()
                        stream(.init(chat: chat, stream: response))
                    }
                }
            case let .complete(result):
                if let error = result.error {
                    completion(.failure(error))
                } else if let first = blocks.first {
                    let result = ChatResult(id: first.id,
                                            object: first.object,
                                            created: first.created,
                                            model: first.model,
                                            choices: [.init(index: first.choices.first?.index ?? 0,
                                                            message: chat,
                                                            finish_reason: first.choices.last?.finish_reason ?? "")],
                                            usage: .init(prompt_tokens: 0,
                                                         completion_tokens: 0,
                                                         total_tokens: 0))
                    completion(.success(result))
                }
            }
        }
    }
    
}

public extension OpenAI {
    
    func get<API: OAIAPI>(_ api: API) async throws -> API.Response {
        let serialize =  AF.request(uri(api.path),
                                    parameters: api.query.serialize(),
                                    headers: .init(.init(headers())))
            .serializingData()
        
        let response = await serialize.response
        guard let data = response.value else {
            throw OAIError.emptyData
        }
        
        if let code = response.response?.statusCode, !(200...299).contains(code) {
            throw try JSONDecoder().decode(OAIErrorResponse.self, from: data).error
        }
        
        return try api.decoder.decode(API.Response.self, from: data)
    }
    
    func models() -> AnyPublisher<ModelsResult, Error> {
        let request = Request<ModelsResult>(body: nil, url: .models, method: .get)
        return performRequest(request: request)
    }
    
    func images(query: ImagesQuery) -> AnyPublisher<ImagesResult, Error> {
        performRequest(request: Request<ImagesResult>(body: query, url: .images))
    }
    
    func embeddings(query: EmbeddingsQuery) -> AnyPublisher<EmbeddingsResult, Error> {
        performRequest(request: Request<EmbeddingsResult>(body: query, url: .embeddings))
    }
    
    func completions(query: CompletionsQuery) -> AnyPublisher<CompletionsResult, Error> {
        performRequest(request: Request<CompletionsResult>(body: query, url: .completions))
    }
    
}

/// billing
public extension OpenAI {

    func billingUsage(_ query: OAIBillingUsage.Query) async throws -> [OAIBillingUsage.DailyCosts] {
        try await get(OAIBillingUsage.init(query)).daily_costs
    }
    
    func billingSubscription() async throws -> OAIBillingSubscription.Response {
        try await get(OAIBillingSubscription())
    }
    
    func billingInvoices() async throws -> [OAIBillingInvoices.Invoice] {
        try await get(OAIBillingInvoices()).data
    }

}
