import PgSQL
import Fluent
import Foundation
import Censor

public final class PrivilegeResourcePivot: PGModel, @unchecked Sendable {
    public static var name: String { "privilege_resource_map" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                        .primary
        public let privilegeId = PGField("privilege_id", .uuid)     .required.unique(composite: name + ".pivot").foreign(Privilege.self, .id, onDelete: .cascade)
        public let resourceId = PGField("resource_id", .uuid)       .required.unique(composite: name + ".pivot")
        public let createdAt = PGField("create_at", .string)        .required
        public let updateAt = PGField("update_at", .string)         .required
        
        public init() {}
    }
    
    public let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: Int?
    
    @Parent(fields.privilegeId)                     public var privilege: Privilege
    @Field(fields.resourceId)                       public var resourceId: UUID
    
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        public var updatedAt: Date!
    
    public required init() {}
    
    public typealias MIG = DefaultMIG<PrivilegeResourcePivot>
}

