import PgSQL
import Foundation
import Policy
@preconcurrency import AnyCodable

extension PM {
    package final class AnyResource: PGModel, @unchecked Sendable  {
        package static var name: String { "resources" }
        
        package struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let name = PGField("name", .string)                     .required
            let type = PGField("type",
                .enum(ResourceList.self, as: "resource_type")
            )                                                       .required
            let data = PGField("data", .json)                       .required
            let createdAt = PGField("create_at", .string)           .required
            let updatedAt = PGField("update_at", .string)           .required
            
            package init() {}
        }
        
        let fields = Fields()
        
        @ID(key: .id)                               package var id: UUID?
        
        @Field(fields.name)                         var name: String
        @Field(fields.type)                         var type: ResourceList
        
        @Siblings(
            through: PrivilegeResourcePivot.self,
            from: \.$secondaryModel,
            to: \.$primaryModel
        )                                           var privileges: [Privilege]
        
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
        
        package init() {}
        
        init<T>(from resource: ResourceModel<T>) {
            self.id = resource.id
            self.name = resource.name
            self.type = resource.type
            self.createdAt = resource.createdAt
            self.updatedAt = resource.updatedAt
        }
        
        package typealias MIG = DefaultMIG<AnyResource>
    }

    package final class ResourceModel<T: Resource>: PGModel, @unchecked Sendable where T.ResourceType == ResourceList  {
        package static var name: String { "resources" }
        
        package struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let name = PGField("name", .string)                     .required
            let type = PGField("type",
                .enum(ResourceList.self, as: "resource_type")
            )                                                       .required
            let data = PGField("data", .json)                       .required
            let createdAt = PGField("create_at", .string)           .required
            let updatedAt = PGField("update_at", .string)           .required
            
            package init() {}
        }
        
        let fields = Fields()
        
        @ID(key: .id)                               package var id: UUID?
        
        @Field(fields.name)                         var name: String
        @Field(fields.type)                         var type: ResourceList
        @Field(fields.data)                         var data: T
        
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
        
        package init() {}
        
        init(from resource: T) {
            self.type = T.type
            self.name = resource.name
            self.data = resource
        }
        
        // data 字段的 json 中有一个 "name" 字段，值应当与表结构中的 name 字段值一致
        // 要解包的 Resource 类型的 type 必须与表结构中 type 的类型相同
        var isValid: Bool {
            T.type == type && data.name == name
        }
        
        package typealias MIG = DefaultMIG<AnyResource>
    }
}
