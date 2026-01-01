import PgSQL
import Fluent
import Foundation
import Censor

public final class Privilege: PGModel, ACLInterface, @unchecked Sendable {
    
    public static let name = "privileges"
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let aclId = PGField("acl_id", .uuid)                     .required.foreign(ACL.self, \.id, onDelete: .cascade)
        public let map = PGField("map", .json)                          .required.def("{}")
        public let expression = PGField("expression", .string)          .required
        public let name = PGField("name", .string)
        public let description = PGField("description", .string)
        public let createdAt = PGField("create_at", .string)            .required
        public let updateAt = PGField("update_at", .string)             .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @Parent(fields.aclId)                           public var acl: ACL
    @Field(fields.map)                              public var map: Censor.Map
    @Field(fields.expression)                       public var expression: String
    @Field(fields.name)                             public var name: String?
    @Field(fields.description)                      public var description: String?
    
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        public var updatedAt: Date!
    
    public init() { }
    
    public typealias MIG = DefaultMIG<Privilege>
}
