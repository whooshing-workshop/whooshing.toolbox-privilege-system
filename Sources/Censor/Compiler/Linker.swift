import ErrorHandle

public extension Censor {
    final class Linker: Sendable {
        private let actions: SendableDictionary<[String], @Sendable ([Value]) -> Res<Value, Errcase>> = .init(
            wrapped: [
                ["asdf", "das"]: { _ in .success(.init(nil)) }
            ]
        )
        
        
    }
}
