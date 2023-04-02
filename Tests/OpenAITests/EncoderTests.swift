//
//  EncoderTests.swift
//  
//
//  Created by linhey on 2023/4/3.
//

import XCTest
import OpenAI

final class EncoderTests: XCTestCase {
    
    let encoder = OpenAI.Tokenizer()
    
    func test_empty_string() {
        let str = ""
        assert(encoder.encode(str) == [])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_space() {
        let str = " "
        assert(encoder.encode(str) == [220])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_tab() {
        let str = "\t"
        assert(encoder.encode(str) == [197])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_simple_text() {
        let str = "This is some text"
        assert(encoder.encode(str) == [1212, 318, 617, 2420])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_multi_token_word() {
        let str = "indivisible"
        assert(encoder.encode(str) == [521, 452, 12843])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_emojis() {
        let str = "hello 👋 world 🌍"
        assert(encoder.encode(str) == [31373, 50169, 233, 995, 12520, 234, 235])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    func test_properties_of_Object() {
        let str = "toString constructor hasOwnProperty valueOf"
        assert(encoder.encode(str) == [1462, 10100, 23772, 468, 23858, 21746, 1988, 5189])
        assert(encoder.decode(encoder.encode(str)) == str)
    }
    
    
}
