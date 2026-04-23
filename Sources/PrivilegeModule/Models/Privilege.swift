import PgSQL
import Fluent
import Foundation
import Policy

public extension PM {
    final class Privilege: PGModel, @unchecked Sendable {
        
        public static var name: String { "privileges" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let name = PGField("name", .string)
            let description = PGField("description", .string)
            let policy = PGField("policy", .string)                     .required
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public let fields = Fields()
        
        @ID(key: .id)                      public var id: UUID?
        
        @Field(fields.name)                             var name: String?
        @Field(fields.description)                      var description: String?
        @Field(fields.policy)                           var policy: String
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
        
        @Siblings(
            through: PrivilegeResourcePivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                               var resources: [AnyResource]
        
        public init() { }
        
        public typealias MIG = DefaultMIG<Privilege>
    }
}

extension PM.Privilege: PolicyType {
    public typealias Model = PrivilegeModule.Privilege
    public static var namePrefix: String { "privilege" }
    public static var typeId: String { "privilege" }
}
