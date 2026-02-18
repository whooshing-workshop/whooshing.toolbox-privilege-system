import Foundation
import ErrorHandle
import PgSQL
import FluentKit
import Policy

public protocol ResourceTypeList: Sendable, Codable, CaseIterable, RawRepresentable
where Self.RawValue == String {
    var migration: any TdeMIG.Type { get }
}

public protocol Action: Codable, Sendable, CaseIterable, RawRepresentable
where Self.RawValue == Int {
    var name: String? { get }
    var description: String? { get }
}

public protocol Resource: Codable, Sendable, PGModel where MIG == DefaultMIG<Self>, IDValue == UUID {
    associatedtype TypeList: ResourceTypeList
    associatedtype Act: Action
    static var type: TypeList { get }
    var createdAt: Date! { get set }
    var updatedAt: Date! { get set }
}

public extension Resource {
    static var name: String { "\(Self.type.rawValue.lowercased())_resources" }
}

public struct AnyAction: Codable, Sendable {
    public let name: String?
    public let code: Int
    public init<T>(_ action: T) where T: Action {
        self.name = action.name
        self.code = action.rawValue
    }
}

public extension PrivilegeModule {
    final class AnyResource: Sendable {
        public let type: ResourceList
        public let t: (any Resource.Type)?
        public let wrapped: (any Resource)?
        public let schema: String
        public let id: UUID
        public let createdAt: Date?
        public let updatedAt: Date?
        
        // 用于包装的 Resource 必须是从数据库中查询取得的，否则会抛出错误
        public init<T: Resource>(_ res: T) throws(Errcase.ErrType) where T.TypeList == ResourceList {
            self.id = try required(throws: Errcase.anyResourceIdParseFailed, category: .external) {
                guard res._$idExists else {
                    throw Errcase.anyResourceIdParseFailed.d("该 Resource Id 不存在，该 Resource 模型并非数据查询所得", category: .external)
                }
                return try res.requireID()
            }
            self.createdAt = res.createdAt
            self.updatedAt = res.updatedAt
            self.wrapped = res
            self.t = T.self
            self.schema = T.schema
            self.type = T.type
        }
        
        // 创建新的实例，可用于 Resource 创建，并非从数据库中查询所得
        public init(
            type: ResourceList,
            schema: String,
            id: UUID
        ) {
            self.type = type
            self.t = nil
            self.wrapped = nil
            self.schema = schema
            self.id = id
            self.createdAt = nil
            self.updatedAt = nil
        }
    }
}
