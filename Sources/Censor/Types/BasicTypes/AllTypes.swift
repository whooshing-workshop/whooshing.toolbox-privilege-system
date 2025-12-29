public extension Censor {
    static let basicTypes = BasicType.allCases.map { $0.realType }
    
    enum BasicType: String, Codable, CaseIterable, Sendable {
        case string             = "StringType"
        case character          = "CharacterType"
        case integer            = "IntegerType"
        case decimal            = "DecimalType"
        case date               = "DateType"
        case uuid               = "UUIDType"
        case bool               = "BoolType"
        case stringType         = "TrueType<StringType>"
        case characterType      = "TrueType<CharacterType>"
        case integerType        = "TrueType<IntegerType>"
        case decimalType        = "TrueType<DecimalType>"
        case dateType           = "TrueType<DateType>"
        case uuidType           = "TrueType<UUIDType>"
        case boolType           = "TrueType<BoolType>"
        case stringArray        = "ArrayType<StringType>"
        case characterArray     = "ArrayType<CharacterType>"
        case integerArray       = "ArrayType<IntegerType>"
        case decimalArray       = "ArrayType<DecimalType>"
        case dateArray          = "ArrayType<DateType>"
        case uuidArray          = "ArrayType<UUIDType>"
        case boolArray          = "ArrayType<BoolType>"
        case anyArray           = "ArrayType<AnyType>"
        
        public var realType: any TypeDeclare.Type {
            switch self {
            case .string:           StringType.self
            case .character:        CharacterType.self
            case .integer:          IntegerType.self
            case .decimal:          DecimalType.self
            case .date:             DateType.self
            case .uuid:             UUIDType.self
            case .bool:             BoolType.self
            case .stringType:       TrueType<StringType>.self
            case .characterType:    TrueType<CharacterType>.self
            case .integerType:      TrueType<IntegerType>.self
            case .decimalType:      TrueType<DecimalType>.self
            case .dateType:         TrueType<DateType>.self
            case .uuidType:         TrueType<UUIDType>.self
            case .boolType:         TrueType<BoolType>.self
            case .stringArray:      ArrayType<StringType>.self
            case .characterArray:   ArrayType<CharacterType>.self
            case .integerArray:     ArrayType<IntegerType>.self
            case .decimalArray:     ArrayType<DecimalType>.self
            case .dateArray:        ArrayType<DateType>.self
            case .uuidArray:        ArrayType<UUIDType>.self
            case .boolArray:        ArrayType<BoolType>.self
            case .anyArray:         ArrayType<AnyType>.self
            }
        }
        
        public init(from type: any TypeDeclare) {
            self = switch Swift.type(of: type).name {
            case StringType.name:                   .string
            case CharacterType.name:                .character
            case IntegerType.name:                  .integer
            case DecimalType.name:                  .decimal
            case DateType.name:                     .date
            case UUIDType.name:                     .uuid
            case BoolType.name:                     .bool
            case TrueType<StringType>.name:         .stringType
            case TrueType<CharacterType>.name:      .characterType
            case TrueType<IntegerType>.name:        .integerType
            case TrueType<DecimalType>.name:        .decimalType
            case TrueType<DateType>.name:           .dateType
            case TrueType<UUIDType>.name:           .uuidType
            case TrueType<BoolType>.name:           .boolType
            case ArrayType<StringType>.name:        .stringArray
            case ArrayType<CharacterType>.name:     .characterArray
            case ArrayType<IntegerType>.name:       .integerArray
            case ArrayType<DecimalType>.name:       .decimalArray
            case ArrayType<DateType>.name:          .dateArray
            case ArrayType<UUIDType>.name:          .uuidArray
            case ArrayType<BoolType>.name:          .boolArray
            case ArrayType<AnyType>.name:           .anyArray
            default: preconditionFailure("非法的类型")
            }
        }
    }
}
