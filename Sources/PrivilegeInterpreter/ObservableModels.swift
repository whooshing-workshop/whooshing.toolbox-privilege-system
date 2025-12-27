import ACL
import Foundation

public protocol ObservableModel {
    var properties: [String: (type: AST.ValueType?, isArray: Bool, nullable: Bool, value: () throws -> Any?)] { get }
}

public protocol Resource: ObservableModel {
    associatedtype Op: ResourceOperation
    
    var label: any Label { get }
    var operations: Set<Op> { get }
}

public protocol ResourceOperation: RawRepresentable, Hashable, CustomStringConvertible, CaseIterable where RawValue == String {}

public extension ResourceOperation {
    var description: String { self.rawValue }
}

public protocol Label: ObservableModel {}

public struct PriviliegeModule: ObservableModel {
    public let id: UUID
    public let name: String
    public let createAt: Date
    
    public var properties: [String : (type: ACL.AST.ValueType?, isArray: Bool, nullable: Bool, value: () throws -> Any?)] {
        [
            "id": (.uuid, false, false, { id }),
            "name": (.string, false, false, { name }),
            "createAt": (.date, false, false, { createAt })
        ]
    }
}
