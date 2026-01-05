import ErrorHandle

extension Censor {
    enum Literal: TokenUnit {
        case string(Variable<Censor.StringType>)
        case character(Variable<Censor.CharacterType>)
        case integer(Variable<Censor.IntegerType>)
        case decimal(Variable<Censor.DecimalType>)
        case date(Variable<Censor.DateType>)
        case uuid(Variable<Censor.UUIDType>)
        case bool(Variable<Censor.BoolType>)
        case trueType(Variable<Censor.TrueType>)
        case identifier(String)
        
        var description: String {
            switch self {
            case .string:               "Literal.STRING"
            case .character:            "Literal.CHAR"
            case .integer:              "Literal.INT"
            case .decimal:              "Literal.DECIMAL"
            case .date:                 "Literal.DATE"
            case .uuid:                 "Literal.UUID"
            case .bool:                 "Literal.BOOL"
            case .trueType:             "Literal.TRUETYPE"
            case .identifier(let s):    "Literal.IDENT(\(s))"
            }
        }
    }
}
