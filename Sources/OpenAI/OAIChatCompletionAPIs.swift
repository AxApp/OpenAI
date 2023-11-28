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
    
     func create(publisher parameter: CreateParameter) throws -> AnyPublisher<OAIChatCompletion, Error> {
        let subject = PassthroughSubject<OAIChatCompletion, Error>()
         
         Task {
             do {
                 let stream = try await create(stream: parameter)
                 for try await chat in stream {
                     subject.send(chat)
                 }
                 subject.send(completion: .finished)
             } catch {
                 subject.send(completion: .failure(error))
             }
         }

        return subject.eraseToAnyPublisher()
    }
    
}
