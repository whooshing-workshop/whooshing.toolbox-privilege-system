import ErrorHandle

extension Censor {
    struct PropertyDeclare: Sendable {
        let returns: @Sendable () -> any TypeDeclare
        
        init(
            returns: @Sendable @escaping @autoclosure () -> any TypeDeclare
        ) {
            self.returns = returns
        }
    }
    
    struct FunctionDeclare: Sendable {
        let returns: @Sendable () -> any TypeDeclare
        let argument: ArgumentDeclare
        
        fileprivate init(
            returns: @Sendable @escaping () -> any TypeDeclare,
            argument: ArgumentDeclare
        ) {
            self.returns = returns
            self.argument = argument
        }
        
        init(@FunctionBuilder _ content: () -> Self) {
            self = content()
        }
    }
    
    @resultBuilder
    struct FunctionBuilder {
        static func buildBlock(
            _ returns: @Sendable @escaping () -> any TypeDeclare,
            _ argument: ArgumentDeclare
        ) -> FunctionDeclare {
            .init(returns: returns, argument: argument)
        }
    }

    enum OperationDeclare {
        struct Prefix: Sendable {
            let selfNullable: Bool
            let returns: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            init(@PrefixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        struct Suffix: Sendable {
            let selfNullable: Bool
            let returns: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
            }
            
            init(@SuffixBuilder _ content: () -> Self) {
                self = content()
            }
        }

        struct Infix: Sendable {
            let selfNullable: Bool
            let returns: @Sendable () -> any TypeDeclare
            let right: @Sendable () -> any TypeDeclare
            
            init(
                returns: @Sendable @escaping () -> any TypeDeclare,
                selfNullable: Bool,
                right: @Sendable @escaping () -> any TypeDeclare
            ) {
                self.returns = returns
                self.selfNullable = selfNullable
                self.right = right
            }
            
            init(@InfixBuilder _ content: () -> Self) {
                self = content()
            }
        }
        
        @resultBuilder
        struct InfixBuilder {
            static func buildBlock(
                _ returns: @Sendable @escaping () -> any TypeDeclare,
                _ selfNullable: Bool,
                _ right: @Sendable @escaping () -> any TypeDeclare
            ) -> OperationDeclare.Infix {
                .init(returns: returns, selfNullable: selfNullable, right: right)
            }
        }

        @resultBuilder
        struct PrefixBuilder {
            static func buildBlock(
                _ returns: @Sendable @escaping () -> any TypeDeclare,
                _ selfNullable: Bool
            ) -> OperationDeclare.Prefix {
                .init(returns: returns, selfNullable: selfNullable)
            }
        }

        @resultBuilder
        struct SuffixBuilder {
            static func buildBlock(
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
