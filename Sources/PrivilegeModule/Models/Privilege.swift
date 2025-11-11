import PgSQL
import Fluent
import Foundation
import ACL

public final class Privilege: PGModel, @unchecked Sendable {
    
    public static let name = "privileges"
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let aclId = PGField("acl_id", .uuid)                     .required.foreign(ACL.self, \.id, onDelete: .cascade)
        public let ast = PGField("ast", .json)                          .required.def("{}")
        public let name = PGField("name", .string)
        public let description = PGField("description", .string)
        public let createdAt = PGField("create_at", .string)            .required
        public let updateAt = PGField("update_at", .string)             .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @Parent(fields.aclId)                           public var acl: ACL
    @Field(fields.ast)                              public var ast: AST
    @Field(fields.name)                             public var name: String?
    @Field(fields.description)                      public var description: String?
    
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        public var updatedAt: Date!
    
    public init() { }
    
    public typealias MIG = DefaultMIG<Privilege>
}
