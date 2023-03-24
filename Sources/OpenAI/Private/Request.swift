//
//  File.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 12/19/22.
//

import Foundation
import Alamofire

class Request<ResultType> {
    
    let body: Codable?
    let url: OpenAI.APIPath
    let timeoutInterval: TimeInterval
    let method: HTTPMethod
    
    init(body: Codable? = nil,
         url: OpenAI.APIPath,
         method: HTTPMethod = .post,
         timeoutInterval: TimeInterval = 60) {
        self.body = body
        self.url = url
        self.method = method
        self.timeoutInterval = timeoutInterval
    }
    
}
