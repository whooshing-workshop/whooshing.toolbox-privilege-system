import ErrorHandle
import Foundation

public extension Censor {
    struct StringType: CollectionTypeDeclare {
        public typealias ElementType = CharacterType
        public typealias RealType = String
        public static let name = "String"
        public let nullable: Bool
        
        public static let properties: [String : Property] = [
            "asInteger": .init {
                Return { IntegerType(nullable: true) }
                Action { .succ(Int64($0.cast(as: String.self))) }
            },
            "asDecimal": .init {
                Return { DecimalType(nullable: true) }
                Action { .succ(Decimal(string: $0.cast())) }
            },
            "asDate": .init {
                Return { DateType(nullable: true) }
                Action { .succ(DateType.dateFormatter.date(from: $0.cast())) }
            },
            "asBool": .init {
                Return { BoolType(nullable: true) }
                Action { .succ($0.cast() == "true" ? true : $0.cast() == "false" ? false : nil) }
            },
            "asUUID": .init {
                Return { UUIDType(nullable: true) }
                Action { .succ(UUID(uuidString: $0.cast())) }
            },
            "count": .init {
                Return { IntegerType(nullable: false) }
                Action { .succ(Int64($0.cast(as: String.self).count)) }
            },
            "last": .init {
                Return { CharacterType(nullable: true) }
                Action { .succ($0.cast(as: String.self).last) }
            }
        ]
        
        public static let functions: [String : Function] = [
            "like": .init {
                Return { BoolType(nullable: false) }
                ArgumentDeclare {
                    (nil, StringType(nullable: false)) >- nil
                }
                FunctionAction {
                    .succ($0.cast(as: String.self).like($1[0].cast()))
                }
            }
        ]
        
        public static let infixOperations: [Operator : [Operation.Infix]] = [
            .plus: [
                .init {
                    Return { StringType(nullable: false) }
                    false
                    StringType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + $1.cast(as: String.self)) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    CharacterType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + String($1.cast(as: Character.self))) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + String($1.cast(as: Int64.self))) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    DecimalType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + $1.cast(as: Decimal.self).description) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    DateType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + DateType.dateFormatter.string(from: $1.cast())) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    UUIDType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + $1.cast(as: UUID.self).uuidString) }
                },
                .init {
                    Return { StringType(nullable: false) }
                    false
                    BoolType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) + ($1.cast() ? "true" : "false")) }
                }
            ],
            .multi: [
                .init {
                    Return { StringType(nullable: false) }
                    false
                    IntegerType(nullable: false)
                    InfixAction { .succ(String(repeating: $0.cast(as: String.self), count: .init($1.cast(as: Int64.self)))) }
                }
            ],
            .equal: [
                .init {
                    Return { BoolType(nullable: false) }
                    true
                    StringType(nullable: true)
                    InfixAction { .succ($0.cast(as: String?.self) == $1.cast(as: String?.self)) }
                }
            ],
            .less: [
                .init {
                    Return { BoolType(nullable: false) }
                    false
                    StringType(nullable: false)
                    InfixAction { .succ($0.cast(as: String.self) < $1.cast(as: String.self)) }
                }
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
