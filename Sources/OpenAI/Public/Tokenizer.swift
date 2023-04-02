//
//  File.swift
//
//
//  Created by linhey on 2023/3/31.
//

import Foundation

public extension OpenAI {
    
    final class Tokenizer {
        
        private lazy var encoder: [String: Int] = {
            guard let url = Bundle.module.url(forResource: "encoder", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
                return [:]
            }
            return object
        }()
        
        private lazy var decoder: [Int: String] = {
            var item = [Int: String]()
            self.encoder.forEach { (key, value) in
                item[value] = key
            }
            return item
        }()
        
        private lazy var bpe_ranks = dictZip()
        private lazy var byte_encoder = bytes_to_unicode()
        private lazy var byte_decoder: [Character: Int] = {
            var item = [Character: Int]()
            byte_encoder.enumerated().forEach { (offset, char) in
                item[char] = offset
            }
            return item
        }()
        private lazy var cache = [String: String]()
        
        public init() {}
    }
    
}

public extension OpenAI.Tokenizer {
    
    func encode(_ text: String) -> [Int] {
        let pattern = try! NSRegularExpression(pattern: "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+", options: [])
        let matches = pattern.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)).map {
            (text as NSString).substring(with: $0.range)
        }
        
        return matches.compactMap { token in
            let btoken = encodeStr(token).compactMap { value in
                byte_encoder[value].description
            }.joined()
            let new_tokens = bpe(btoken)
                .split(separator: " ")
                .map(\.description)
                .compactMap({ encoder[$0] })
            return new_tokens
        }.flatMap({ $0 })
    }
    
    func decode(_ tokens: [Int]) -> String {
        var text = tokens.compactMap({ decoder[$0] }).joined(separator: "")
        text = decodeStr(text.compactMap({ byte_decoder[$0] }))
        return text
    }
    
}

private extension OpenAI.Tokenizer {
    
    struct Pair: Hashable {
        let x: String
        let y: String
    }
    
    
    func bpe(_ token: String) -> String {
        if let cached = cache[token] {
            return cached
        }
        
        var word = token.map({ $0.description })
        var pairs = get_pairs(word)
        
        if pairs.isEmpty {
            return token
        }
        
        while true {
            var minPairs = [Int: Pair]()
            for pair in pairs {
                let rank = bpe_ranks[pair] ?? Int(10e10)
                minPairs[Int(rank)] = pair
            }
            
            let bigram = minPairs[minPairs.keys.min()!]!
            
            if bpe_ranks[bigram] == nil {
                break
            }
            
            let first = bigram.x
            let second = bigram.y
            var new_word = [String]()
            var i = 0
            
            while i < word.count {
                if let j =  word.dropFirst(i).firstIndex(of: first) {
                    new_word += word[i..<j]
                    i = j
                    
                    if i < word.count - 1, word[i] == first, word[i+1] == second {
                        new_word.append(first + second)
                        i += 2
                    } else {
                        new_word.append(word[i])
                        i += 1
                    }
                } else {
                    new_word += word[i..<word.count]
                    break
                }
            }
            
            word = new_word
            if word.count == 1 {
                break
            } else {
                pairs = get_pairs(word)
            }
        }
        
        let result = word.joined(separator: " ")
        cache[token] = result
        print(token, result)
        return result
    }
    
    func get_pairs(_ chars: [String]) -> [Pair] {
        guard !chars.isEmpty else {
            return .init()
        }
        var pairs = [Pair]()
        var prevChar = chars[0]
        for char in chars.dropFirst() {
            pairs.append(.init(x: prevChar.description, y: char.description))
            prevChar = char
        }
        return pairs
    }
    
    func getPairs(word: String) -> Set<String> {
        var pairs = Set<String>()
        var prevChar = word[word.startIndex]
        for char in word[word.index(after: word.startIndex)...] {
            pairs.insert(String([prevChar, char]))
            prevChar = char
        }
        return pairs
    }
    
    func range(x: Int, y: Int) -> Range<Int> {
        return x..<y
    }
    
    func ord(_ x: Character) -> Int {
        return Int(x.unicodeScalars.first!.value)
    }
    
    func chr(_ x: Int) -> Character {
        return .init(UnicodeScalar(x)!)
    }
    
    func encodeStr(_ str: String) -> [Int] {
        guard let data = str.data(using: .utf8) else {
            return []
        }
        return [UInt8](data).map({ Int($0) })
    }
    
    func decodeStr(_ arr: [Int]) -> String {
        let list = arr.map({ UInt8($0) })
        let data = Data(list)
        return .init(data: data, encoding: .utf8) ?? ""
    }
    
    func dictZip() -> [Pair: Int] {
        guard let url = Bundle.module.url(forResource: "vocab", withExtension: "bpe"),
              let data = try? Data.init(contentsOf: url),
              let str = String(data: data, encoding: .utf8) else {
            return [:]
        }
        
        var item = [Pair: Int]()
        str
            .split(separator: "\n")
            .dropFirst()
            .compactMap({ str -> Pair? in
                let words = str.split(separator: " ")
                guard let x = words.first, let y = words.last else {
                    return nil
                }
                return Pair(x: String(x), y: String(y))
            })
            .enumerated()
            .forEach({ (offset, element) in
                item[element] = offset
            })
        
        return item
    }
    
    func bytes_to_unicode() -> [Character] {
        ["Ā","ā","Ă","ă","Ą","ą",
         "Ć","ć","Ĉ","ĉ","Ċ","ċ",
         "Č","č","Ď","ď","Đ","đ",
         "Ē","ē","Ĕ","ĕ","Ė","ė",
         "Ę","ę","Ě","ě","Ĝ","ĝ",
         "Ğ","ğ","Ġ","!","\"","#",
         "$","%","&","'","(",")",
         "*","+",",","-",".","/",
         "0","1","2","3","4","5",
         "6","7","8","9",":",";",
         "<","=",">","?","@","A",
         "B","C","D","E","F","G",
         "H","I","J","K","L","M",
         "N","O","P","Q","R","S",
         "T","U","V","W","X","Y",
         "Z","[","\\","]","^","_",
         "`","a","b","c","d","e",
         "f","g","h","i","j","k",
         "l","m","n","o","p","q",
         "r","s","t","u","v","w",
         "x","y","z","{","|","}",
         "~","ġ","Ģ","ģ","Ĥ","ĥ",
         "Ħ","ħ","Ĩ","ĩ","Ī","ī",
         "Ĭ","ĭ","Į","į","İ","ı",
         "Ĳ","ĳ","Ĵ","ĵ","Ķ","ķ",
         "ĸ","Ĺ","ĺ","Ļ","ļ","Ľ",
         "ľ","Ŀ","ŀ","Ł","ł","¡",
         "¢","£","¤","¥","¦","§",
         "¨","©","ª","«","¬","Ń",
         "®","¯","°","±","²","³",
         "´","µ","¶","·","¸","¹",
         "º","»","¼","½","¾","¿",
         "À","Á","Â","Ã","Ä","Å",
         "Æ","Ç","È","É","Ê","Ë",
         "Ì","Í","Î","Ï","Ð","Ñ",
         "Ò","Ó","Ô","Õ","Ö","×",
         "Ø","Ù","Ú","Û","Ü","Ý",
         "Þ","ß","à","á","â","ã",
         "ä","å","æ","ç","è","é",
         "ê","ë","ì","í","î","ï",
         "ð","ñ","ò","ó","ô","õ",
         "ö","÷","ø","ù","ú","û",
         "ü","ý","þ","ÿ"]
    }
    
}
