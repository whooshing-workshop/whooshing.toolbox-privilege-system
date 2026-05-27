import Foundation
import ErrorHandle
@preconcurrency import AnyCodable

public protocol Resource: Sendable, Codable, Hashable {
    associatedtype ResourceType: ResourceTypeList
    associatedtype Operations: OperationList
    static var type: ResourceType { get }
    
    var name: String { get }
    
    var json: [String: AnyCodable] { get }
    static var mirrors: [PartialKeyPath<Self>: [String]] { get }
}

public protocol OperationList: Sendable, Codable, CaseIterable, RawRepresentable
where Self.RawValue == String {}


public protocol ResourceTypeList: Sendable, Codable, CaseIterable, RawRepresentable, Hashable
where Self.RawValue == String {}
