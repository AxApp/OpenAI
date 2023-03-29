//
//  File.swift
//  
//
//  Created by linhey on 2023/3/23.
//

import Foundation
import Combine

///MARK: - Embeddings
public extension OpenAI {

    struct EmbeddingsQuery: Codable {
        /// ID of the model to use.
        public let model: String
        /// Input text to get embeddings for
        public let input: String

        public init(model: OpenAIModel, input: String) {
            self.model = model.name
            self.input = input
        }
    }

    struct EmbeddingsResult: Codable {

        public struct Embedding: Codable {
            public let object: String
            public let embedding: [Double]
            public let index: Int
        }
        public let data: [Embedding]
    }

    func embeddings(query: EmbeddingsQuery) -> AnyPublisher<EmbeddingsResult, Error> {
        performRequest(request: Request<EmbeddingsResult>(body: query, url: .embeddings))
    }
}

