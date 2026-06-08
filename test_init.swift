import Foundation

@propertyWrapper
struct Passive<Value> {
    var wrappedValue: Value
}

struct MyStruct {
    let name: String
    @Passive var id: UUID
    
    init(name: String) {
        self.name = name
    }
}

extension MyStruct: Decodable {
    init(from decoder: Decoder) throws {
        self.init(name: "test")
        self.id = UUID()
    }
}

print("Compiles!")
