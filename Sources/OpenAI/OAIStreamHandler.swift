//
//  File.swift
//  
//
//  Created by linhey on 2023/9/27.
//

import Foundation
import OpenAICore
import Combine

class OAIStreamHandler: NSObject {
    
    let subject = PassthroughSubject<OAIClientResponse, Error>()
    
    private lazy var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var task: URLSessionDataTask?
       
    func connect(with request: URLRequest, data: Data) {
        task = session.uploadTask(with: request, from: data)
        task?.resume()
    }
    
    func disconnect() {
        subject.send(completion: .finished)
        task?.cancel()
    }

}

extension OAIStreamHandler: URLSessionDataDelegate {
    
    /// It will be called several times, each time could return one chunk of data or multiple chunk of data
    /// The JSON look liks this:
    /// `data: {"id":"chatcmpl-6yVTvD6UAXsE9uG2SmW4Tc2iuFnnT","object":"chat.completion.chunk","created":1679878715,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"role":"assistant"},"index":0,"finish_reason":null}]}`
    /// `data: {"id":"chatcmpl-6yVTvD6UAXsE9uG2SmW4Tc2iuFnnT","object":"chat.completion.chunk","created":1679878715,"model":"gpt-3.5-turbo-0301","choices":[{"delta":{"content":"Once"},"index":0,"finish_reason":null}]}`
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let eventString = String(data: data, encoding: .utf8) else { return }
        let lines = eventString.split(separator: "\n")
        for line in lines {
            if line.hasPrefix("data:"), line != "data: [DONE]" {
                if let data = String(line.dropFirst(5)).data(using: .utf8) {
                    subject.send(.init(data: data, response: dataTask.httpResponse ?? .init(status: .accepted)))
                } else {
                    disconnect()
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            subject.send(completion: .failure(error))
        } else {
            subject.send(completion: .finished)
        }
    }
}
