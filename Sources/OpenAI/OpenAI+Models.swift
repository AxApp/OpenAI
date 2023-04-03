//
//  File.swift
//  
//
//  Created by linhey on 2023/3/23.
//

import Foundation
#if canImport(Combine)
import Combine
#endif

public extension OpenAI {
    
    struct ModelsResult: Codable {
        struct Model: Codable {
            let id: String
            let object: String
            let created: TimeInterval
            let ownedBy: String?
            let permission: [Permission]
        }
        
        struct Permission: Codable {
            let id: String
            let object: String
            let created: Int
            let allowCreateEngine: Bool
            let allowSampling: Bool
            let allowLogprobs: Bool
            let allowSearchIndices: Bool
            let allowView: Bool
            let allowFineTuning: Bool
            let organization: String
            let group: String?
            let isBlocking: Bool
            
            enum CodingKeys: String, CodingKey {
                case id
                case object
                case created
                case allowCreateEngine = "allow_create_engine"
                case allowSampling = "allow_sampling"
                case allowLogprobs = "allow_logprobs"
                case allowSearchIndices = "allow_search_indices"
                case allowView = "allow_view"
                case allowFineTuning = "allow_fine_tuning"
                case organization
                case group
                case isBlocking = "is_blocking"
            }
        }
        
        let data: [Model]
        let object: String
        let root: String?
    }
    
#if canImport(Combine)
    func models() -> AnyPublisher<ModelsResult, Error>  {
        let request = Request<ModelsResult>(body: nil, url: .models, method: .get)
        return performRequest(request: request)
    }
#endif
    
}
