import PgSQL
import Foundation
import Policy
import Fluent

public final class Domain: PGModel, @unchecked Sendable {
    
    public static let name = "domains"
    
    public struct Fields: PGFields {
        let id = PGField("id", .int64)                          .primary
        let name = PGField("name", .string)
        let description = PGField("description", .string)
        let createdAt = PGField("created_at", .datetime)           .required
        let updatedAt = PGField("updated_at", .datetime)           .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: Int64?
    
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
    @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<Domain>
}
