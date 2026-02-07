import PgSQL
import Foundation
import Policy

final class Domain: PGModel, @unchecked Sendable {
    
    static let name = "domains"
    
    struct Fields: PGFields {
        let id = PGField("id", .int64)                          .primary
        let name = PGField("name", .string)
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int64?
    
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
    
    init() {}
    
    typealias MIG = DefaultMIG<Domain>
}
