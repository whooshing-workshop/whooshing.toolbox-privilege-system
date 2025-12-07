public enum DTO {}

public extension DTO {
    protocol Status {}
    
    enum Prepare: Status {}
    enum Queried: Status {}
    
    @propertyWrapper
    struct Passive<T>: @unchecked Sendable {
        private var value: T?
        
        public var wrappedValue: T {
            get {
                guard let v = value else { fatalError("该属性值未被赋值，不可获取未被赋值的属性值") }
                return v
            }
            set { value = newValue }
        }
        
        public internal(set) var projectedValue: T? {
            get { value }
            set { value = newValue }
        }
        
        public init(wrappedValue: T) { self.value = wrappedValue }
        public init() { self.value = nil }
    }
    
    @propertyWrapper
    struct Protect<T>: @unchecked Sendable {
        private var value: T?
        
        public var wrappedValue: T {
            get {
                guard let v = value else { fatalError("该属性值被保护(隐藏)，不可获取") }
                return v
            }
            set { value = newValue }
        }
        
        public internal(set) var projectedValue: T? {
            get { value }
            set { value = newValue }
        }
        
        public init(wrappedValue: T) { self.value = wrappedValue }
        public init() { self.value = nil }
    }
}
