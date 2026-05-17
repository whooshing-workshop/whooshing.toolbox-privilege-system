import PgSQL
import Foundation
import Policy
import Fluent
@preconcurrency import AnyCodable

extension PM {
    public final class AnyResource: PGModel, @unchecked Sendable  {
        public static var name: String { "resources" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let name = PGField("name", .string)                         .required
            let type = PGField("type",
                .enum(ResourceList.self, as: "resource_type")
            )                                                           .required
            let data = PGField("data", .json)                           .required
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        let fields = Fields()
        
        @ID(key: .id)                               public var id: UUID?
        
        @Field(fields.name)                         var name: String
        @Enum(fields.type)                          var type: ResourceList
        @Field(fields.data)                         var data: [String: AnyCodable]
        
        @Siblings(
            through: PrivilegeAnyResourcePivot.self,
            from: \.$secondaryModel,
            to: \.$primaryModel
        )                                           var privileges: [Privilege]
        
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
        
        public init() {}
        
        init<T>(from resource: ResourceModel<T>) {
            self.id = resource.id
            self.name = resource.name
            self.type = resource.type
            self.data = resource.data.json
            self.createdAt = resource.createdAt
            self.updatedAt = resource.updatedAt
            
            self.$id.exists = resource.$id.exists
            self._$idExists = resource._$idExists
            self._$id.exists = resource._$id.exists
            self.$privileges.fromId = self.id
        }
        
        public typealias MIG = DefaultMIG<AnyResource>
    }

    public final class ResourceModel<T: Resource>: PGModel, @unchecked Sendable where T.ResourceType == ResourceList  {
        public static var name: String { "resources" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let name = PGField("name", .string)                     .required
            let type = PGField("type",
                .enum(ResourceList.self, as: "resource_type")
            )                                                       .required
            let data = PGField("data", .json)                       .required
            let createdAt = PGField("created_at", .datetime)        .required
            let updatedAt = PGField("updated_at", .datetime)        .required
            
            public init() {}
        }
        
        let fields = Fields()
        
        @ID(key: .id)                               public var id: UUID?
        
        @Field(fields.name)                         var name: String
        @Enum(fields.type)                          var type: ResourceList
        @Field(fields.data)                         var data: T
        
        @Siblings(
            through: PrivilegeResourcePivot.self,
            from: \.$secondaryModel,
            to: \.$primaryModel
        )                                           var privileges: [Privilege]
        
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
        
        public init() {}
        
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
        
        func fill() -> Self {
            self.$privileges.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<AnyResource>
    }
}
