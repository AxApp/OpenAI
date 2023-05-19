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
    
    struct ChatStreamItem {
        public let chat: OAIChat.Chat
        public let stream: DataStreamRequest.Stream<Data, Never>?
    }
    
    func chats(_ query: OAIChat.Query) async throws -> OAIChat.Response {
        var query = query
        query.stream = false
        return try await post(OAIChat(query))
    }
    
    func chats(stream query: OAIChat.Query, interval: TimeInterval? = nil) -> AsyncThrowingStream<ChatStreamItem, Error> {
        if let stream = query.stream, stream {
            return .init { continuation in
                var date = Date()
                try? chats(query: query) { result in
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
            }
        } else {
            return .init {
                let response = try await self.chats(query)
                return .init(chat: response.choices.first?.message ?? .init(role: .assistant, content: ""), stream: nil)
            }
        }
    }
    
    func chats(query: OAIChat.Query) -> AnyPublisher<ChatStreamItem, Error> {
        let suject = PassthroughSubject<ChatStreamItem, Error>()
        do {
            try chats(query: query) { result in
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
        } catch {
            suject.send(completion: .failure(error))
        }
        return suject.eraseToAnyPublisher()
    }
    
    func chats(query: OAIChat.Query,
               stream: @escaping (_ stream: ChatStreamItem) -> Void,
               completion: @escaping (Result<OAIChat.Response, Error>) -> Void) throws {
        guard let url = URL(string: uri(.chats)) else {
            completion(.failure(OAIError.invalidURL))
            return
        }
        
        var request = try URLRequest(url: url,
                                 method: .post,
                                 headers: .init(headers().map({HTTPHeader(name: $0.key, value: $0.value)})))
        var query = query
        query.stream = true
        request.httpBody = try JSONEncoder().encode(query)
        
        let decoder = JSONDecoder()
        var blocks = [OAIChat.DeltaChatResult]()
        var chat = OAIChat.Chat(role: .assistant, content: "")
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
                            .compactMap({ try? decoder.decode(OAIChat.DeltaChatResult.self, from: $0) })
                        blocks.append(contentsOf: list)
                        chat.content += list.compactMap(\.choices.first?.delta?.content).joined()
                        stream(.init(chat: chat, stream: response))
                    }
                }
            case let .complete(result):
                if let error = result.error {
                    completion(.failure(error))
                } else if let first = blocks.first {
                    let result = OAIChat.Response(id: first.id,
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

    func post<API: OAIAPI>(_ api: API) async throws -> API.Response {
        let serialize = AF.request(uri(api.path),
                                       method: .post,
                                       headers: .init(.init(headers())), requestModifier: { request in
            request.httpBody = try api.query.serializeData()
        }).serializingData()
        
        let response = await serialize.response
        guard let data = response.value else {
            throw OAIError.emptyData
        }
        
        if let code = response.response?.statusCode, !(200...299).contains(code) {
            throw try JSONDecoder().decode(OAIErrorResponse.self, from: data).error
        }
        
        return try api.decoder.decode(API.Response.self, from: data)
    }
    
    func get<API: OAIAPI>(_ api: API) async throws -> API.Response {
        let serialize = try AF.request(uri(api.path),
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
    
    func models() async throws -> OAIModels.Response {
        return try await get(OAIModels())
    }
    
    func images(_ query: OAIImages.Query) async throws -> OAIImages.Response {
        return try await post(OAIImages(query: query))
    }
    
    func embeddings(_ query: OAIEmbeddings.Query) async throws -> OAIEmbeddings.Response {
        return try await post(OAIEmbeddings(query: query))
    }
    
    func embeddings(_ query: OAICompletions.Query) async throws -> OAICompletions.Response {
        return try await post(OAICompletions(query: query))
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
