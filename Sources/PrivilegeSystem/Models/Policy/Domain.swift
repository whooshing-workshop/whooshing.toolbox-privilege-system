import PgSQL
import Foundation
import Policy

package final class Domain: PGModel, @unchecked Sendable {
    
    package static let name = "domains"
    
    package struct Fields: PGFields {
        let id = PGField("id", .int64)                          .primary
        let name = PGField("name", .string)
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        package init() {}
    }
    
    package static let fields = Fields()
    
    @ID(custom: fields.id.key)                      package var id: Int64?
    
    @Field(fields.name)                             var name: String?
    @Field(fields.description)                      var description: String?
    
    @Siblings(
        through: UserDomainPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )                                               var users: [User]
    @Siblings(
        through: DomainGroupPivot.self,
        from: \.$primaryModel,
        to: \.$secondaryModel
    )                                               var groups: [UGroup]
    @Children(
        for: \DomainPolicy.$parent
    )                                               var policies: [DomainPolicy]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    package init() {}
    
    package typealias MIG = DefaultMIG<Domain>
}
