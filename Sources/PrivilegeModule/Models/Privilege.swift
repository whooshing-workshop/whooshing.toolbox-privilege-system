import PgSQL
import Fluent
import Foundation
import Policy

package extension PM {
    final class Privilege: PGModel, @unchecked Sendable {
        
        package static var name: String { "privileges" }
        
        package struct Fields: PGFields {
            let id = PGField("id", .int64)                          .primary
            let name = PGField("name", .string)
            let description = PGField("description", .string)
            let policy = PGField("policy", .string)                 .required
            let createdAt = PGField("created_at", .datetime)           .required
            let updatedAt = PGField("updated_at", .datetime)           .required
            
            package init() {}
        }
        
        package let fields = Fields()
        
        @ID(custom: fields.id.key)                      package var id: Int64?
        
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
        
        package init() { }
        
        package typealias MIG = DefaultMIG<Privilege>
    }
}

extension PM.Privilege: PolicyType {
    package typealias Model = PrivilegeModule.Privilege
    package static var namePrefix: String { "privilege" }
    package static var typeId: String { "privilege" }
}
