import PgSQL
import Fluent
import Foundation
import Policy

package extension PrivilegeModule {
    final class Privilege: PGModel, @unchecked Sendable {
        
        package static var name: String { "privileges" }
        
        package struct Fields: PGFields {
            package let id = PGField("id", .int64)                          .primary
            package let name = PGField("name", .string)
            package let description = PGField("description", .string)
            package let policy = PGField("policy", .string)                 .required
            package let createdAt = PGField("create_at", .string)           .required
            package let updatedAt = PGField("update_at", .string)           .required
            
            package init() {}
        }
        
        package let fields = Fields()
        
        @ID(custom: fields.id.key)                      package var id: Int64?
        
        @Field(fields.name)                             package var name: String?
        @Field(fields.description)                      package var description: String?
        @Field(fields.policy)                           package var policy: String
        
        @Timestamp(fields.createdAt, on: .create)       package var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       package var updatedAt: Date!
        
        package init() { }
        
        package typealias MIG = DefaultMIG<Privilege>
    }
}
