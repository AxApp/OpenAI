//
//  File.swift
//  
//
//  Created by linhey on 2023/5/19.
//

import Foundation

public protocol OAIAPIQuery {
    
    func serialize() -> [String: Any]
    
}
