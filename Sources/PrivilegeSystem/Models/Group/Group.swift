import PgSQL
import Fluent
import Foundation
import Policy

public final class UGroup: PGModel, @unchecked Sendable {
    
    public static let name = "groups"
    
    public struct Fields: PGFields {
        let id = PGField("id", .uuid)                               .primary
        let parentId = PGField("parent_id", .uuid)                  .foreign(UGroup.self, .id, onDelete: .cascade)
                                                                    .unique(composite: "group.unique")
        let name = PGField("name", .string)                         .required
                                                                    .unique(composite: "group.unique")
        let description = PGField("description", .string)
        let createdAt = PGField("created_at", .datetime)            .required
        let updatedAt = PGField("updated_at", .datetime)            .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(key: .id)                                   public var id: UUID?
    
    @OptionalParent(fields.parentId)                var parent: UGroup?
    
    @Field(fields.name)                             var name: String
    @Field(fields.description)                      var description: String?
    
    @Children(for: \Path.$descendant)               var supers: [Path]
    @Children(for: \Path.$ancestor)                 var childs: [Path]
    @Siblings(
        through: UserGroupPivot.self,
        from: \.$group,
        to: \.$user
    )                                               var users: [User]
    @Siblings(
        through: RoleGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )                                               var groupRoles: [Role]
    @Siblings(
        through: DomainGroupPivot.self,
        from: \.$secondaryModel,
        to: \.$primaryModel
    )                                               var domains: [Domain]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<UGroup>
    
    func fill() -> Self {
        self.$supers.fromId = self.id
        self.$childs.fromId = self.id
        self.$users.fromId = self.id
        self.$groupRoles.fromId = self.id
        self.$domains.fromId = self.id
        return self
    }
}

// 仅仅为了某些小众需求，一般不使用
extension UGroup: Hashable {
    public static func == (lhs: UGroup, rhs: UGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
