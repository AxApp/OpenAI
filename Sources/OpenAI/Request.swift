//
//  File.swift
//  
//
//  Created by Sergii Kryvoblotskyi on 12/19/22.
//

import Foundation
import Alamofire
import OpenAICore

public class Request<ResultType> {
    
    public let body: Codable?
    public let url: OAIPath
    public let timeoutInterval: TimeInterval
    public let method: HTTPMethod
    
    public init(body: Codable? = nil,
                url: OAIPath,
                method: HTTPMethod = .post,
                timeoutInterval: TimeInterval = 60) {
        self.body = body
        self.url = url
        self.method = method
        self.timeoutInterval = timeoutInterval
    }
    
}
