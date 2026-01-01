import ErrorHandle

public extension Censor {
    struct PropertyDeclare: Sendable {
        public let returns: @Sendable () -> any TypeDeclare
        
        public init(
            returns: @Sendable @escaping @autoclosure () -> any TypeDeclare
        ) {
            self.returns = returns
        }
    }
    
    struct FunctionDeclare: Sendable {
        public let returns: @Sendable () -> any TypeDeclare
        public let argument: ArgumentDeclare
        
        fileprivate init(
            returns: @Sendable @escaping () -> any TypeDeclare,
            argument: ArgumentDeclare
        ) {
            self.returns = returns
            self.argument = argument
        }
        
        public init(@FunctionBuilder _ content: () -> Self) {
            self = content()
        }
    }
    
    @resultBuilder
    struct FunctionBuilder {
        public static func buildBlock(
            _ returns: @Sendable @escaping () -> any TypeDeclare,
            _ argument: ArgumentDeclare
        ) -> FunctionDeclare {
            .init(returns: returns, argument: argument)
        }
    }

    enum OperationDeclare {
        public struct Prefix: Sendable {
            public let selfNullable: Bool
            public let returns: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            public init(@PrefixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        public struct Suffix: Sendable {
            public let selfNullable: Bool
            public let returns: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            public init(@SuffixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        public struct Infix: Sendable {
            public let selfNullable: Bool
            public let returns: @Sendable () -> any TypeDeclare
            public let right: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool,
                right: @Sendable @escaping () -> any TypeDeclare
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.right = right
            }
            
            public init(@InfixBuilder _ content: () -> Self) {
                self = content()
            }
        }
        
        @resultBuilder
        public struct InfixBuilder {
            public static func buildBlock(
                _ returns: @Sendable @escaping () -> any TypeDeclare,
                _ selfNullable: Bool,
                _ right: @Sendable @escaping () -> any TypeDeclare
            ) -> OperationDeclare.Infix {
                .init(returns: returns, selfNullable: selfNullable, right: right)
            }
        }

        @resultBuilder
        public struct PrefixBuilder {
            public static func buildBlock(
                _ returns: @Sendable @escaping () -> any TypeDeclare,
                _ selfNullable: Bool
            ) -> OperationDeclare.Prefix {
                .init(returns: returns, selfNullable: selfNullable)
            }
        }

        @resultBuilder
        public struct SuffixBuilder {
            public static func buildBlock(
                _ returns: @Sendable @escaping () -> any TypeDeclare,
                _ selfNullable: Bool
            ) -> OperationDeclare.Suffix {
                .init(returns: returns, selfNullable: selfNullable)
            }
        }
    }

    static func Right(_ type: @Sendable @escaping () -> any TypeDeclare) -> @Sendable () -> any TypeDeclare { type }
    static func Return(_ type: @Sendable @escaping () -> any TypeDeclare) -> @Sendable () -> any TypeDeclare { type }
}
