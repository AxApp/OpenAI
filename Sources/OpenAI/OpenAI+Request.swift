//
//  File.swift
//
//
//  Created by linhey on 2023/5/19.
//

import Foundation
import Combine
import OpenAICore
import HTTPTypes
import HTTPTypesFoundation

public class OAIClient: OAIClientProtocol {
    
    public static let shared = OAIClient()
    
    private var streams = Set<OAIStreamHandler>()
    private var cancellables = Set<AnyCancellable>()
    
    public func data(for request: HTTPRequest) async throws -> OAIClientResponse {
        let response = try await URLSession.shared.data(for: request)
        return .init(data: response.0, response: response.1)
    }
    
    public func upload(for request: HTTPRequest, from bodyData: Data) async throws -> OAIClientResponse {
        let response = try await URLSession.shared.upload(for: request, from: bodyData)
        return .init(data: response.0, response: response.1)
    }
    
    public func stream(for request: HTTPRequest, from bodyData: Data) throws -> AsyncThrowingStream<OAIClientResponse, Error> {
        
        guard let urlRequest = URLRequest(httpRequest: request) else {
            throw OAIError(.failedToConvertHTTPRequestToURLRequest)
        }
        
        let (stream, continuation) = AsyncThrowingStream<OAIClientResponse, Error>.makeStream()
        let hander = OAIStreamHandler()
        hander.subject.sink { [weak self, weak hander] completion in
            switch completion {
            case .finished:
                continuation.finish()
            case .failure(let error):
                continuation.finish(throwing: error)
            }
            guard let self = self, let hander = hander else { return }
            self.streams.remove(hander)
        } receiveValue: { response in
            continuation.yield(response)
        }.store(in: &cancellables)
        streams.update(with: hander)
        hander.connect(with: urlRequest, data: bodyData)
        return stream
    }
    
}

public struct OpenAI {
    
    public let client: OAIClientProtocol
    public let serivce: OAISerivce
    
    public let chatCompletion: OAIChatCompletionAPIs
    public let models: OAIModelAPIs

    public init(client: OAIClientProtocol = OAIClient.shared, serivce: OAISerivce) {
        self.client = client
        self.serivce = serivce
        chatCompletion = .init(client: client, serivce: serivce)
        models = .init(client: client, serivce: serivce)
    }
    
}
