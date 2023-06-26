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
    
    func chats(_ query: OAIChat.Query) async throws -> OAIChat.Response {
        var query = query
        query.stream = false
        return try await post(OAIChat(query))
    }
    
    func chats(_ builder: (_ query: inout OAIChat.Query) -> Void) async throws -> OAIChat.Response {
        var query = OAIChat.Query()
        builder(&query)
        return try await chats(query)
    }
    
    func chats(stream query: OAIChat.Query, interval: TimeInterval? = nil) async -> AsyncThrowingStream<OAIChat.Chat, Error> {
        let (stream, continuation) = AsyncThrowingStream<OAIChat.Chat, Error>.makeStream()
        do {
            if query.stream == false {
                if let message = try await self.chats(query).choices.first?.message {
                    continuation.yield(message)
                }
                continuation.finish()
            } else {
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
                            continuation.yield(chat)
                        }
                        continuation.finish()
                    }
                }
            }
        } catch {
            continuation.finish(throwing: error)
        }
        
        return stream
    }
    
    func chats(query: OAIChat.Query) -> AnyPublisher<OAIChat.Chat, Error> {
        let suject = PassthroughSubject<OAIChat.Chat, Error>()
        do {
            try chats(query: query) { result in
                suject.send(result)
            } completion: { result in
                switch result {
                case .failure(let error):
                    suject.send(completion: .failure(error))
                case .success(let value):
                    if let chat = value.choices.first?.message {
                        suject.send(chat)
                    }
                    suject.send(completion: .finished)
                }
            }
        } catch {
            suject.send(completion: .failure(error))
        }
        return suject.eraseToAnyPublisher()
    }
    
   static func merge(deltas: [OAIChat.DeltaChatResult]) -> OAIChat.Chat {
         
        var role: String = ""
        var content: String?
        var function_call: OAIChat.FunctionCall?
        
        let deltas = deltas.compactMap(\.choices.first?.delta)
        for delta in deltas {
            if let value = delta.role {
                role = value
            }
            if let value = delta.content {
                if content == nil {
                    content = value
                } else {
                    content?.append(value)
                }
            }
            
            if let value = delta.function_call {
                if function_call == nil {
                    function_call = .init(name: value.name ?? "", arguments: value.arguments ?? "")
                    continue
                }
                
                if let value = value.name {
                    function_call?.name = value
                }
                
                if let value = value.arguments {
                    function_call?.arguments.append(value)
                }
            }
        }
        
        return .init(role: role,
                     content: content ?? "",
                     function_call: function_call)

    }
    
    func chats(query: OAIChat.Query,
               stream: @escaping (_ stream: OAIChat.Chat) -> Void,
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
        request.httpBody = try query.serialize().rawData()
        
        let decoder = JSONDecoder()
        var blocks = [OAIChat.DeltaChatResult]()
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
                        let result = OpenAI.merge(deltas: blocks)
                        stream(result)
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
                                                            message: OpenAI.merge(deltas: blocks),
                                                            finish_reason: first.choices.last?.finish_reason ?? .none)],
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
            request.httpBody = try api.query.serialize().rawData()
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
                                       parameters: api.query.serialize() as? [String: Any] ?? [:],
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
