import PgSQL
import Foundation
import Policy
import ResourceMacros

final class LabelResourcePivot: PGModel, @unchecked Sendable {
    public static var name: String { "label_resource_map" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                    .primary
        public let labelId = PGField("label_id", .uuid)         .required.unique(composite: name + ".pivot")
        public let resourceId = PGField("resource_id", .uuid)   .required.unique(composite: name + ".pivot")
        public let createdAt = PGField("create_at", .string)    .required
        public let updateAt = PGField("update_at", .string)     .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: Int?
    
    @Field(fields.labelId)                          public var labelId: UUID
    @Field(fields.resourceId)                       public var resourceId: UUID
    
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        public var updatedAt: Date!
    
    public required init() {}
    
    public typealias MIG = DefaultMIG<LabelResourcePivot>
}
