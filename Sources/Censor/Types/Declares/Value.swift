import Foundation

public extension Censor {
    struct Value: CustomStringConvertible, @unchecked Sendable {
        public let content: Any?
        public var isNull: Bool { content == nil }
        
        public init<T>(_ content: T) {
            self.content = content
        }
        
        public var description: String {
            self.content == nil ? Keyword.null.rawValue : String(describing: self.content!)
        }
        
        @Sendable public func cast<T>(as: T.Type = T.self) -> T {
            content as! T
        }
    }
}

extension Censor.Value: Codable {
    enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    enum CodingTypes: String, Codable, Sendable {
        case string, character, integer, decimal, bool, date, uuid, array, null
    }
    
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(CodingTypes.self, forKey: .type)
        
        switch type {
        case .string:
            let value = try c.decode(String.self, forKey: .value)
            self.content = value
            
        case .character:
            let value = try c.decode(String.self, forKey: .value)
            self.content = value.first!
            
        case .integer:
            let value = try c.decode(Int64.self, forKey: .value)
            self.content = value
            
        case .decimal:
            let value = try c.decode(Decimal.self, forKey: .value)
            self.content = value
            
        case .bool:
            let value = try c.decode(Bool.self, forKey: .value)
            self.content = value
            
        case .date:
            let value = try c.decode(Date.self, forKey: .value)
            self.content = value
            
        case .uuid:
            let value = try c.decode(UUID.self, forKey: .value)
            self.content = value
            
        case .array:
            let value = try c.decode([Censor.Value].self, forKey: .value)
            self.content = value.map { $0.content }
            
        case .null:
            self.content = nil
        }
    }
    
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        
        if let v = content as? [Any?] {
            try c.encode(CodingTypes.array, forKey: .type)
            try c.encode(v.map { Censor.Value($0) }, forKey: .value)
        } else if let v = content as? String {
            try c.encode(CodingTypes.string, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if let v = content as? Character {
            try c.encode(CodingTypes.character, forKey: .type)
            try c.encode(String(v), forKey: .value)
        } else if let v = content as? Int64 {
            try c.encode(CodingTypes.integer, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if let v = content as? Decimal {
            try c.encode(CodingTypes.decimal, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if let v = content as? Bool {
            try c.encode(CodingTypes.bool, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if let v = content as? Date {
            try c.encode(CodingTypes.date, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if let v = content as? UUID {
            try c.encode(CodingTypes.uuid, forKey: .type)
            try c.encode(v, forKey: .value)
        } else if content == nil {
            try c.encode(CodingTypes.null, forKey: .type)
        } else {
            preconditionFailure("不受支持的类型 \(String(describing: Swift.type(of: content)))")
        }
    }
}

//public extension Expression {
//    static func getType(of value: Any?) -> (any TypeDeclare)? {
//        if let v = value as? [Any?] {
//            return ArrayType(nullable: false)
//        } else if let v = value as? String {
//            return StringType(nullable: false)
//        } else if let v = value as? Character {
//            return CharacterType(nullable: false)
//        } else if let v = value as? Int64 {
//            return IntegerType(nullable: false)
//        } else if let v = value as? Decimal {
//            return DecimalType(nullable: false)
//        } else if let v = value as? Bool {
//            return BoolType(nullable: false)
//        } else if let v = value as? Date {
//            return DateType(nullable: false)
//        } else if let v = value as? UUID {
//            return UUIDType(nullable: false)
//        } else if value == nil {
//            return nil
//        } else {
//            preconditionFailure("不受支持的类型 \(String(describing: type(of: value)))")
//        }
//    }
//}
