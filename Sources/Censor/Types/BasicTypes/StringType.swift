import ErrorHandle
import Foundation

public extension Censor {
    struct StringType: CollectionTypeDeclare {
        public typealias ElementType = CharacterType
        public typealias RealType = String
        public static let name = "String"
        public let nullable: Bool
        
        public let properties: [String : PropertyDeclare] = [
            "asInteger": .init { IntegerType(nullable: true) },
            "asDecimal": .init { DecimalType(nullable: true) },
            "asDate": .init { DateType(nullable: true) },
            "asBool": .init { BoolType(nullable: true) },
            "asUUID": .init { UUIDType(nullable: true) },
            "count": .init { IntegerType(nullable: false) },
            "last": .init { CharacterType(nullable: true) }
        ]
        
        public let functions: [String : FunctionDeclare] = [
            "like": .init {
                Return { BoolType(nullable: false) }
                ArgumentDeclare {
                    (nil, StringType(nullable: false)) >- nil
                }
            }
        ]
        
        public let infixOperations: [Operator.Infix : [OperationDeclare.Infix]] = [
            .plus: [
                .init {
                    Return { StringType(nullable: false) }
                    false
                    StringType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    CharacterType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    DateType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    UUIDType(nullable: false)
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    BoolType(nullable: false)
                }
            ],
            .multi: [
                .init {
                    Return { StringType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    StringType(nullable: true)
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    StringType(nullable: false)
                }
            ]
        ]
        
        public static let propertyActions: [String : ExecutableAction] = [
            "asInteger": .init { .succ(Int64($0.first!.cast(as: String.self))) },
            "asDecimal": .init { .succ(Decimal(string: $0.first!.cast())) },
            "asDate": .init { .succ(DateType.dateFormatter.date(from: $0.first!.cast())) },
            "asBool": .init { .succ($0.first!.cast() == "true" ? true : $0.first!.cast() == "false" ? false : nil) },
            "asUUID": .init { .succ(UUID(uuidString: $0.first!.cast())) },
            "count": .init { .succ(Int64($0.first!.cast(as: String.self).count)) },
            "last": .init { .succ($0.first!.cast(as: String.self).last) }
        ]
        
        public static let functionActions: [String : ExecutableAction] = [
            "like": .init { .succ($0[0].cast(as: String.self).like($0[1].cast())) }
        ]
        
        public static let infixOpActions: [Operator.Infix : [String : ExecutableAction]] = [
            .plus: [
                StringType.name: .init { .succ($0[0].cast(as: String.self) + $0[1].cast(as: String.self)) },
                CharacterType.name: .init { .succ($0[0].cast(as: String.self) + String($0[1].cast(as: Character.self))) },
                IntegerType.name: .init { .succ($0[0].cast(as: String.self) + String($0[1].cast(as: Int64.self))) },
                DecimalType.name: .init { .succ($0[0].cast(as: String.self) + $0[1].cast(as: Decimal.self).description) },
                DateType.name: .init { .succ($0[0].cast(as: String.self) + DateType.dateFormatter.string(from: $0[1].cast())) },
                UUIDType.name: .init { .succ($0[0].cast(as: String.self) + $0[1].cast(as: UUID.self).uuidString) },
                BoolType.name: .init { .succ($0[0].cast(as: String.self) + ($0[1].cast() ? "true" : "false")) }
            ],
            .multi: [
                IntegerType.name: .init { .succ(String(repeating: $0[0].cast(as: String.self), count: .init($0[1].cast(as: Int64.self)))) }
            ],
            .equal: [
                StringType.name: .init { .succ($0[0].cast(as: String?.self) == $0[1].cast(as: String?.self)) }
            ],
            .less: [
                StringType.name: .init { .succ($0[0].cast(as: String.self) < $0[1].cast(as: String.self)) }
            ]
        ]
        
        public init(nullable: Bool) {
            self.nullable = nullable
        }
    }
}

extension String {
    func like(_ pattern: String) -> Bool {
        // 1. 转义正则表达式中的特殊字符 (例如 . + ? 等)
        var regexPattern = NSRegularExpression.escapedPattern(for: pattern)
        
        // 2. 将 SQL 通配符转换为 Regex 符号
        // 注意顺序：先处理转义后的 % 和 _
        regexPattern = regexPattern.replacingOccurrences(of: "%", with: ".*")
        regexPattern = regexPattern.replacingOccurrences(of: "_", with: ".")
        
        // 3. 加上锚点，确保全匹配
        regexPattern = "^\(regexPattern)$"
        
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return false
        }
        
        let range = NSRange(location: 0, length: self.utf16.count)
        return regex.firstMatch(in: self, range: range) != nil
    }
}
