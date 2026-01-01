import PgSQL
import Foundation
import Censor

final class Domain: PGModel, ACLInterface, @unchecked Sendable {
    
    static let name = "domains"
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let aclId = PGField("acl_id", .uuid)                    .required.foreign(ACL.self, \.id, onDelete: .cascade)
        let map = PGField("map", .json)                         .required.cons(.sql(.default("{}")))
        let expression = PGField("expression", .string)         .required
        let name = PGField("name", .string)
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @Parent(fields.aclId)                           var acl: ACL
    @Field(fields.map)                              var map: Censor.Map
    @Field(fields.expression)                       var expression: String
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
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
    
    typealias MIG = DefaultMIG<Domain>
}
