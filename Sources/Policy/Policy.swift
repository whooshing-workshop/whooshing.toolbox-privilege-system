import PgSQL
import Fluent
import Foundation

public protocol PolicyType: Sendable where Model.IDValue == Int64 {
    associatedtype Model: PGModel
    static var namePrefix: String { get }
    static var typeId: String { get }
}

package extension PolicyType {
    static var regoHead: String { "" }
}

public final class PolicyExp<T: PolicyType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.namePrefix + "_policies" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let parentId = PGField("\(T.namePrefix)_id", .int64)     .required
                                                                        .foreign(T.Model.self, .id, onDelete: .cascade)
        public let moduleId = PGField("module_id", .uuid)               .required
        public let policy = PGField("policy", .string)                  .required
        public let createdAt = PGField("create_at", .string)            .required
        public let updatedAt = PGField("update_at", .string)            .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @Parent(fields.parentId)                        public var parent: T.Model
    @Field(fields.moduleId)                         public var moduleId: UUID
    @Field(fields.policy)                           public var policy: String
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)       public var updatedAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<PolicyExp<T>>
}
