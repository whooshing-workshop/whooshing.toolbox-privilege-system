import Foundation
@preconcurrency import AnyCodable

public protocol Resource: Sendable, Codable {
    associatedtype ResourceType: ResourceTypeList
    static var type: ResourceType { get }
    var name: String { get }
    static var mirrors: [PartialKeyPath<Self>: [String]] { get }
}

public protocol ResourceTypeList:
    Sendable, Codable, CaseIterable, RawRepresentable
    where Self.RawValue == String {}

extension Resource {
    var model: ResourceModel<Self> {
        .init(from: self)
    }
}

struct AnyResource: Resource {
    static let type: ResourceType = .none
    static var mirrors: [PartialKeyPath<AnyResource> : [String]] { [:] }
    let name: String
    enum ResourceType: String, ResourceTypeList {
        case none
    }
}
