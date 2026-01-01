public extension Censor {
    static let basicTypes = BasicType.allCases.map { $0.realType }
    
    enum BasicType: String, Codable, CaseIterable, Sendable {
        case string             = "String"
        case character          = "Character"
        case integer            = "Integer"
        case decimal            = "Decimal"
        case date               = "Date"
        case uuid               = "UUID"
        case bool               = "Bool"
        
        public var realType: any TypeDeclare.Type {
            switch self {
            case .string:           StringType.self
            case .character:        CharacterType.self
            case .integer:          IntegerType.self
            case .decimal:          DecimalType.self
            case .date:             DateType.self
            case .uuid:             UUIDType.self
            case .bool:             BoolType.self
            }
        }
        
        public init(from type: any TypeDeclare) {
            guard let r = Self.init(rawValue: Swift.type(of: type).name) else {
                preconditionFailure("非法的类型")
            }
            
            self = r
        }
    }
}
