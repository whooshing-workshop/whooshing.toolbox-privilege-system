import Foundation
import ErrorHandle
import Logging
import LoggingAdvanced
@preconcurrency import AnyCodable

public protocol Resource: Sendable, Codable, Hashable, Loggerable, CustomStringConvertible {
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

public extension Resource {
    var description: String {
        formatQuery(self.json)
    }
    
    var rtype: ResourceType {
        Self.type
    }
}

public struct AnyOperation: Sendable, Decodable, Loggerable, CustomStringConvertible {
    public let rawValue: String
    
    public init<T: OperationList>(op: T) {
        self.rawValue = op.rawValue
    }
    
    public var description: String {
        self.rawValue
    }
}

package func formatQuery(_ query: [String: AnyCodable]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let data = try encoder.encode(query)
        return String(data: data, encoding: .utf8) ?? "\(query)"
    } catch {
        return "\(query)"
    }
}
