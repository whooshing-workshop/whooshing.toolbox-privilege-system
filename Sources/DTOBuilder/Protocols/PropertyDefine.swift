import Foundation
import Fluent
import PgSQL
import Collections
import NIOAdvanced
import ErrorHandle
import LoggingAdvanced
import NIOConcurrencyHelpers
import Query
@preconcurrency import AnyCodable

public extension DTO {
    
    enum PropertyCodingKeys: String, DTO.CodingKey {
        case idsLoaded
        case loaded
        case value
        case id
        case ids
    }
    
    protocol Property: DTO.Model where CodingKeys == PropertyCodingKeys {}
}

package protocol __Property: DTO.Property {
    associatedtype Value: Hashable, Sendable, Encodable
    var loaded: Bool { get }
    var value: Value? { get }
    
    // 有些 property 需要额外的 id 属性，例如 SuperProperty，需要存储外键 id
    // 该 hasId 若为 false，则不将 contentId 编码到 Encodable 中，也不参与 log 打印以及 json 的转换
    static var hasId: Bool { get }
    var contentId: UUID? { get }
}

public extension DTO.Property {}

extension __Property {
    package var value: Value? { nil }
    package static var hasId: Bool { false }
    package var contentId: UUID? { nil }
    
    public var summaryKeys: [CodingKeys] {
        Self.hasId ? [.id, .value] : [.value]
    }
    
    public var maps: [CodingKeys : AnyHashable?] {
        var value: [CodingKeys : AnyHashable?] = [
            .loaded: .init(obj: loaded),
            .value: .init(obj: self.value)
        ]
        if Self.hasId { value[.id] = .init(obj: self.contentId) }
        return value
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.loaded, forKey: .loaded)
        try container.encodeIfPresent(self.value, forKey: .value)
        if Self.hasId {
            try container.encodeIfPresent(self.contentId, forKey: .id)
        }
    }
}
