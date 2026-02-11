import PgSQL
import Fluent
import Foundation
import Policy

extension PrivilegeModule {
    final class PrivilegeResourcePivot: PGModel, @unchecked Sendable {
        static var name: String { "resource_privilege_map" }
        
        struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let privilegeId = PGField("privilege_id", .int64)       .required
                                                                    .unique(composite: name + ".pivot")
            let resourceId = PGField("resource_id", .uuid)          .required
                                                                    .unique(composite: name + ".pivot")
                                                                    .foreign(Privilege.self, .id, onDelete: .cascade)
            let type = PGField("type",
                .enum(
                    ResourceList.self,
                    as: "resource_privilege_map.type"
                )
            )                                                       .required
                                                                    .unique(composite: name + ".pivot")
            let createdAt = PGField("create_at", .string)           .required
            let updateAt = PGField("update_at", .string)            .required
            
            init() {}
        }
        
        let fields = Fields()
        
        @ID(custom: fields.id.key)                      var id: UUID?
        
        @Parent(fields.privilegeId)                     var privilege: Privilege
        @Field(fields.resourceId)                       var resourceId: UUID
        @Enum(fields.type)                              var type: ResourceList
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
        
        required init() {}
        
        init(
            privilegeId: Privilege.IDValue,
            resourceId: UUID,
            resourceType: ResourceList
        ) {
            self.$privilege.id = privilegeId
            self.resourceId = resourceId
            self.type = resourceType
        }
        
        typealias MIG = DefaultMIG<PrivilegeResourcePivot>
    }
}
