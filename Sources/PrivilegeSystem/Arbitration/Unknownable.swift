import NIOConcurrencyHelpers

extension PrivilegeSystem.Arbitrator {
    @propertyWrapper
    struct Unknownable<T: Sendable & Encodable>: @unchecked Sendable, Encodable {
        private var value: T?
        private let lock = NIOLock()
        
        private(set) var isUnknown = true
        
        var wrappedValue: T {
            get {
                lock.withLock {
                    guard let v = value else { fatalError("该属性值未被赋值，不可获取未被赋值的属性值") }
                    return v
                }
            }
            set {
                lock.withLock{ value = newValue }
            }
        }
        
        var projectedValue: T? {
            get {
                lock.withLock { value }
            }
            set {
                lock.withLock {
                    isUnknown = false
                    value = newValue
                }
            }
        }
        
        init() {
            self.value = nil
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(wrappedValue)
        }
    }
}
