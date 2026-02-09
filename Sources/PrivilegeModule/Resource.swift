import Foundation
@preconcurrency import AnyCodable

public protocol Resource: Sendable, Codable {
    associatedtype ResourceType: ResourceTypeList
    associatedtype Operations: OperationList
    static var type: ResourceType { get }
    var name: String { get }
    static var mirrors: [PartialKeyPath<Self>: [String]] { get }
}

public protocol OperationList: Sendable, Codable, CaseIterable, RawRepresentable
where Self.RawValue == String {}

//struct AnyResource: Resource {
//    static let type: ResourceType = .none
//    static var mirrors: [PartialKeyPath<AnyResource> : [String]] { [:] }
//    let name: String
//    enum ResourceType: String, ResourceTypeList {
//        case none
//    }
//    enum Operations: String, OperationList {
//        case none
//    }
//}
