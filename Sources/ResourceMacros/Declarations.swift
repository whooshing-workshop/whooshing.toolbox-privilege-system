public protocol ObservableModel {
    static var vars: [String: PartialKeyPath<Self>] { get }
}

public protocol Resource: ObservableModel {
    associatedtype OpList: OperationList
    
    var label: any Label { get }
}

public protocol OperationList: RawRepresentable, CustomStringConvertible, CaseIterable where RawValue == String {}

public extension OperationList {
    var description: String { self.description }
}

public protocol Label: ObservableModel {}
