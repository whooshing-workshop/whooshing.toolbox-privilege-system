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
        case array              = "Array"
        case stringType         = "String.Type"
        case characterType      = "Character.Type"
        case integerType        = "Integer.Type"
        case decimalType        = "Decimal.Type"
        case dateType           = "Date.Type"
        case uuidType           = "UUID.Type"
        case boolType           = "Bool.Type"
        case arrayType          = "Array.Type"
        
        public var realType: any TypeDeclare.Type {
            switch self {
            case .string:           StringType.self
            case .character:        CharacterType.self
            case .integer:          IntegerType.self
            case .decimal:          DecimalType.self
            case .date:             DateType.self
            case .uuid:             UUIDType.self
            case .bool:             BoolType.self
            case .array:            ArrayType.self
            case .stringType:       TrueType<StringType>.self
            case .characterType:    TrueType<CharacterType>.self
            case .integerType:      TrueType<IntegerType>.self
            case .decimalType:      TrueType<DecimalType>.self
            case .dateType:         TrueType<DateType>.self
            case .uuidType:         TrueType<UUIDType>.self
            case .boolType:         TrueType<BoolType>.self
            case .arrayType:        TrueType<ArrayType>.self
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
