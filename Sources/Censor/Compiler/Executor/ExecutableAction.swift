import ErrorHandle

extension Censor {
    struct ExecutableAction: Sendable {
        let content: @Sendable (ArgumentMap) -> Res<Value, Errcase>
        
        init(content: @Sendable @escaping (ArgumentMap) -> Res<Value, Errcase>) {
            self.content = content
        }
    }
    
    struct ArgumentMap: @unchecked Sendable, Collection {
        let startIndex: Int
        let endIndex: Int
        
        private let pointer: UnsafePointer<Value>
        private let pointees: [Int]
        
        func index(after i: Int) -> Int {
            pointees.index(after: i)
        }
        
        subscript(position: Int) -> Value {
            pointer[pointees[position]]
        }
        
        init(pointer: UnsafePointer<Value>, pointees: [Int]) {
            self.pointer = pointer
            self.pointees = pointees
            self.startIndex = pointees.startIndex
            self.endIndex = pointees.endIndex
        }
    }
}
