//
//  File.swift
//  
//
//  Created by linhey on 2023/9/28.
//

import Foundation
import OpenAICore
import Combine

public extension OAIChatCompletionAPIs {
    
     func create(publisher parameter: CreateParameter) async throws -> AnyPublisher<OAIChatCompletion, Error> {
        let stream  = try await create(stream: parameter)
        let subject = PassthroughSubject<OAIChatCompletion, Error>()
        var completion = OAIChatCompletion()
        do {
            for try await chat in stream {
                completion = merge(completion: chat, to: completion)
                subject.send(completion)
            }
            subject.send(completion: .finished)
        } catch {
            subject.send(completion: .failure(error))
        }
        
        return subject.eraseToAnyPublisher()
    }
    
}
