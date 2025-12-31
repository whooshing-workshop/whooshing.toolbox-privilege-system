import ErrorHandle

public extension Censor {
    indirect enum Map: Sendable, Codable {
        case value(Value)
        case action(String, [Self])
    }
}

public extension Censor {
    struct ExecutableAction: Sendable {
        let content: @Sendable ([Value]) -> Res<Value, Errcase>
        
        init(content: @Sendable @escaping ([Value]) -> Res<Value, Errcase>) {
            self.content = content
        }
        
//        public init(@ActionBuilder _ content: () -> Self) {
//            self = content()
//        }
    }
    
//    @resultBuilder
//    struct ActionBuilder {
//        public static func buildBlock(
//            _ content: @Sendable @escaping ([Value]) -> Res<Value, Errcase>
//        ) -> ExecutableAction {
//            .init(content: content)
//        }
//    }
}
