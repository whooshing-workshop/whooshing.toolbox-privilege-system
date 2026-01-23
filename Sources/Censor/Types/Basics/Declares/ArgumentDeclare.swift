import ErrorHandle

extension Censor {
    struct ArgumentDeclare: Sendable {
        let labels: [String?]
        let types: [@Sendable () -> any TypeDeclare]
        let defaults: [Value?]
        
        struct Define: Sendable {
            let label: String?
            let type: @Sendable() -> any TypeDeclare
            let `default`: Value?
        }
        
        init(
            @ArgumentDeclareBuilder
            _ components: () -> [ArgumentDeclare.Define]
        ) {
            var labels: [String?] = []
            var types: [@Sendable () -> any TypeDeclare] = []
            var defaults: [Value?] = []
            for define in components() {
                labels.append(define.label)
                types.append(define.type)
                defaults.append(define.default)
            }
            self.labels = labels
            self.types = types
            self.defaults = defaults
        }
    }
}

extension Censor.ArgumentDeclare: Collection {
    var startIndex: Int { types.startIndex }
    var endIndex: Int { types.endIndex }
    
    func index(after i: Int) -> Int { types.index(after: i) }
    
    subscript(position: Int) -> (label: String?, type: any Censor.TypeDeclare, def: Censor.Value?) {
        (
            labels[position],
            types[position](),
            defaults[position]
        )
    }
    
    func validate(types: [any Censor.TypeDeclare]) -> Bool {
        self.enumerated().allSatisfy { types[$0.offset] == $0.element.type }
    }
}

infix operator >-

func >- (left: (String?, @Sendable () -> any Censor.TypeDeclare), right: Censor.Value?) -> Censor.ArgumentDeclare.Define {
    .init(label: left.0, type: left.1, default: right)
}

@resultBuilder
struct ArgumentDeclareBuilder: Sendable {
    static func buildBlock(_ components: Censor.ArgumentDeclare.Define...) -> [Censor.ArgumentDeclare.Define] {
        components
    }
}

extension Result where Success == Censor.Value {
    static func succ(_ value: Any?) -> Self {
        .success(.init(value))
    }
}
