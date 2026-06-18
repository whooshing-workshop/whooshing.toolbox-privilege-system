import PgSQL
import Foundation
import DTOBuilder
import Fluent
import PrivilegeModule

public extension __SDBM {
    final class Domain: PGModel, @unchecked Sendable {
        
        public static let name = "domains"
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let name = PGField("name", .string)
            let description = PGField("description", .string)
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public static let fields = Fields()
        
        @ID(key: .id)                                   public var id: UUID?
        
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
        )                                               var groups: [Group]
        @Children(
            for: \DomainPolicy.$parent
        )                                               var policies: [DomainPolicy]
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
        
        public init() {}
        
        func fill() -> Self {
            self.$users.fromId = self.id
            self.$groups.fromId = self.id
            self.$policies.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<Domain>
    }
}
