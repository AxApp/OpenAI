//
//  File.swift
//  
//
//  Created by linhey on 2023/3/21.
//

import Foundation
#if canImport(Combine)
import Combine
#endif
import Alamofire

///MARK: - Chat
public extension OpenAI {
    
    struct ChatQuery: Codable {
        /// ID of the model to use. Currently, only gpt-3.5-turbo and gpt-3.5-turbo-0301 are supported.
        public var model: String
        /// The messages to generate chat completions for
        public var messages: [Chat]
        /// What sampling temperature to use, between 0 and 2. Higher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and  We generally recommend altering this or top_p but not both.
        public var temperature: Double?
        /// An alternative to sampling with temperature, called nucleus sampling, where the model considers the results of the tokens with top_p probability mass. So 0.1 means only the tokens comprising the top 10% probability mass are considered.
        public var top_p: Double?
        /// How many chat completion choices to generate for each input message.
        public var n: Int?
        /// If set, partial message deltas will be sent, like in ChatGPT. Tokens will be sent as data-only `server-sent events` as they become available, with the stream terminated by a data: [DONE] message.
        public var stream: Bool?
        /// Up to 4 sequences where the API will stop generating further tokens. The returned text will not contain the stop sequence.
        public var stop: [String]?
        /// The maximum number of tokens to generate in the completion.
        public var max_tokens: Int?
        /// Number between -2.0 and 2.0. Positive values penalize new tokens based on whether they appear in the text so far, increasing the model's likelihood to talk about new topics.
        public var presence_penalty: Double?
        /// Number between -2.0 and 2.0. Positive values penalize new tokens based on their existing frequency in the text so far, decreasing the model's likelihood to repeat the same line verbatim.
        public var frequency_penalty: Double?
        ///Modify the likelihood of specified tokens appearing in the completion.
        public var logit_bias: [String: Int]?
        /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
        public var user: String?
        
        public init(model: OpenAIModel, messages: [Chat], temperature: Double? = nil, top_p: Double? = nil, n: Int? = nil, stream: Bool? = nil, stop: [String]? = nil, max_tokens: Int? = nil, presence_penalty: Double? = nil, frequency_penalty: Double? = nil, logit_bias: [String : Int]? = nil, user: String? = nil) {
            self.model = model.name
            self.messages = messages
            self.temperature = temperature
            self.top_p = top_p
            self.n = n
            self.stream = stream
            self.stop = stop
            self.max_tokens = max_tokens
            self.presence_penalty = presence_penalty
            self.frequency_penalty = frequency_penalty
            self.logit_bias = logit_bias
            self.user = user
        }
        
        public init(model: String, messages: [Chat], temperature: Double? = nil, top_p: Double? = nil, n: Int? = nil, stream: Bool? = nil, stop: [String]? = nil, max_tokens: Int? = nil, presence_penalty: Double? = nil, frequency_penalty: Double? = nil, logit_bias: [String : Int]? = nil, user: String? = nil) {
            self.model = model
            self.messages = messages
            self.temperature = temperature
            self.top_p = top_p
            self.n = n
            self.stream = stream
            self.stop = stop
            self.max_tokens = max_tokens
            self.presence_penalty = presence_penalty
            self.frequency_penalty = frequency_penalty
            self.logit_bias = logit_bias
            self.user = user
        }
        
    }
    
    struct Chat: Codable {
        public var role: String
        public var content: String
        
        public enum Role: String, Codable {
            case system
            case assistant
            case user
        }
        
        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
        
        public init(role: Role, content: String) {
            self.init(role: role.rawValue, content: content)
        }
    }
    
    struct ChatError: Codable, LocalizedError {
        public let message: String
        public let type: String?
        public let code: String?
        public var errorDescription: String? { message }
    }
    
    struct ChatErrorResult: Codable {
        public let error: ChatError
    }
    
    struct ChatResult: Codable {
        
        public struct Choice: Codable {
            public let index: Int
            public let message: Chat
            public let finish_reason: String
        }
        
        public struct Usage: Codable {
            public let prompt_tokens: Int
            public let completion_tokens: Int
            public let total_tokens: Int
        }
        
        public let id: String
        public let object: String
        public let created: TimeInterval
        public let model: String
        public let choices: [Choice]
        public let usage: Usage
    }
    
    private struct DeltaChatResult: Codable {
        struct Chat: Codable {
            public let role: String?
            public let content: String?
        }
        
        struct Choice: Codable {
            let delta: Chat?
            var index: Int
            var finish_reason: String?
        }
        
        let id: String
        let object: String
        let created: TimeInterval
        let model: String
        let choices: [Choice]
    }
    
    #if canImport(Combine)
    func chats(query: ChatQuery, timeoutInterval: TimeInterval = 60.0) -> AnyPublisher<Chat, Error> {
        let suject = PassthroughSubject<Chat, Error>()
        chats(query: query, timeoutInterval: timeoutInterval) { result in
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
        return suject.eraseToAnyPublisher()
    }
    
    func chats(query: ChatQuery,
               timeoutInterval: TimeInterval = 60.0,
               stream: @escaping (_ result: Chat) -> Void,
               completion: @escaping (Result<ChatResult, Error>) -> Void) {
        var query = query
        query.stream = true
        guard let request = makeRequest(Request<ChatQuery>(body: query, url: .chats, timeoutInterval: timeoutInterval)) else {
            completion(.failure(OpenAIError.invalidURL))
            return
        }
        
        let decoder = JSONDecoder()
        var blocks = [DeltaChatResult]()
        var chat = Chat(role: .assistant, content: "")
        let parser = EventStreamParser()
        AF.streamRequest(request).responseStream { response in
            switch response.event {
            case let .stream(result):
                switch result {
                case let .success(data):
                    let list = parser.append(data: data)
                        .compactMap({ $0.data(using: .utf8) })
                        .compactMap({ try? decoder.decode(DeltaChatResult.self, from: $0) })
                    blocks.append(contentsOf: list)
                    chat.content += list.compactMap(\.choices.first?.delta?.content).joined()
                    stream(chat)
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
    #endif
}
