//
//  EventSource.swift
//  EventSource
//
//  Created by Andres on 2/13/15.
//  Copyright (c) 2015 Inaka. All rights reserved.
//

import Foundation
import Combine

public enum EventSourceState {
    case connecting
    case open
    case closed
}

public enum OpenAIStream {

    public enum Fail: Error {
        case data(Data)
        case error(Error)
    }
    
    public enum StateKind: Int {
        case stream
        case connecting
        case closed
    }
    
    public enum State {
        case stream(Message)
        case connecting
        case closed
        
        var kind: StateKind {
            switch self {
            case .stream: return .stream
            case .connecting: return .connecting
            case .closed: return .closed
            }
        }
    }

    public struct Message {
        let id: String?
        let event: String?
        let data: String?
    }

}


public protocol EventSourceProtocol {
    var headers: [String: String] { get }
    
    /// RetryTime: This can be changed remotly if the server sends an event `retry:`
    var retryTime: Int { get }
    
    /// URL where EventSource will listen for events.
    var url: URL { get }
    
    /// The last event id received from server. This id is neccesary to keep track of the last event-id received to avoid
    /// receiving duplicate events after a reconnection.
    var lastEventId: String? { get }
    
    /// Method used to connect to server. It can receive an optional lastEventId indicating the Last-Event-ID
    ///
    /// - Parameter lastEventId: optional value that is going to be added on the request header to server.
    func connect(lastEventId: String?)
    
    /// Method used to disconnect from server.
    func disconnect()
}

open class EventSource: NSObject, EventSourceProtocol, URLSessionDataDelegate {
    
    static let DefaultRetryTime = 3000
    public let urlRequest: URLRequest
    public var url: URL { urlRequest.url! }
    private(set) public var lastEventId: String?
    private(set) public var retryTime = EventSource.DefaultRetryTime
    private(set) public var headers: [String: String]
    private(set) public var state = CurrentValueSubject<OpenAIStream.State, OpenAIStream.Fail>(.closed)
    
    private var eventStreamParser: EventStreamParser?
    private var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main
    private var urlSession: URLSession?
    
    public init(urlRequest: URLRequest) {
        self.urlRequest = urlRequest
        self.headers = urlRequest.allHTTPHeaderFields ?? [:]
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1
        super.init()
    }
    
    public func connect(lastEventId: String? = nil) {
        eventStreamParser = EventStreamParser()
        state.value = .connecting
        let configuration = sessionConfiguration(lastEventId: lastEventId)
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        urlSession?.dataTask(with: urlRequest).resume()
    }
    
    public func disconnect() {
        state.value = .closed
        urlSession?.invalidateAndCancel()
    }
    
    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        completionHandler(.allow)
        state.value = .stream(.init(id: nil, event: nil, data: nil))
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard state.value.kind == .stream else {
            return
        }
        
        guard let statusCode = (dataTask.response as? HTTPURLResponse)?.statusCode,
              validate(statusCode: statusCode) else {
            state.send(completion: .failure(.data(data)))
            return
        }
        
        if let events = eventStreamParser?.append(data: data) {
            notifyReceivedEvents(events)
        }
    }
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard state.value.kind == .stream else {
            return
        }
        if let error {
            state.send(completion: .failure(.error(error)))
        } else {
            state.send(completion: .finished)
        }
    }
    
    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
        
        var newRequest = request
        self.headers.forEach { newRequest.setValue($1, forHTTPHeaderField: $0) }
        completionHandler(newRequest)
    }
}

internal extension EventSource {
    
    func sessionConfiguration(lastEventId: String?) -> URLSessionConfiguration {
        
        var additionalHeaders = headers
        if let eventID = lastEventId {
            additionalHeaders["Last-Event-Id"] = eventID
        }
        
        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"
        
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfiguration.httpAdditionalHeaders = additionalHeaders
        
        return sessionConfiguration
    }
    
}

private extension EventSource {
    
    func notifyReceivedEvents(_ events: [Event]) {
        
        for event in events {
            lastEventId = event.id
            retryTime = event.retryTime ?? EventSource.DefaultRetryTime
            
            if event.onlyRetryEvent == true {
                continue
            }
            
            if event.event == nil || event.event == "message" {
               let message = OpenAIStream.Message(id: event.id, event: "message", data: event.data)
                state.value = .stream(message)
            }
        }
    }
    
    // Following "5 Processing model" from:
    // https://www.w3.org/TR/2009/WD-eventsource-20090421/#handler-eventsource-onerror
    func shouldReconnect(statusCode: Int) -> Bool {
        switch statusCode {
        case 200:
            return false
        case _ where statusCode > 200 && statusCode < 300:
            return true
        default:
            return false
        }
    }
    
    func validate(statusCode: Int) -> Bool {
        (200...299).contains(statusCode)
    }

}
