import Foundation
import DTOBuilder
@preconcurrency import AnyCodable

public extension __SDBM {
    final class AnyResource: PGModel, @unchecked Sendable  {
        public static var name: String { "resources" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let appId = PGField("app_id", .string)                      .required.unique
            let type = PGField("type", .string)                         .required
            let data = PGField("data", .json)                           .required
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        let fields = Fields()
        
        @ID(key: .id)                               public var id: UUID?
        
        @Field(fields.appId)                        var appId: String
        @Field(fields.type)                         var type: String
        @Field(fields.data)                         var data: [String: AnyCodable]
        
        @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
        
        public init() {}
        
        init<T, G>(from resource: PrivilegeModule<G>.__DBM.ResourceModel<T>) {
            self.id = resource.id
            self.appId = resource.appId
            self.type = resource.type.rawValue
            self.data = resource.data.json
            self.createdAt = resource.createdAt
            self.updatedAt = resource.updatedAt
            
            self.$id.exists = resource.$id.exists
            self._$idExists = resource._$idExists
            self._$id.exists = resource._$id.exists
        }
        
        public typealias MIG = DefaultMIG<__SDBM.AnyResource>
    }
}

extension PM.__DBM {
    public final class ResourceModel<T: Resource>: PGModel, @unchecked Sendable where T.ResourceType == ResourceList  {
        public static var name: String { "resources" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let appId = PGField("app_id", .string)                  .required.unique
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
        
        @Field(fields.appId)                        var appId: String
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
            self.appId = resource.appId
            self.data = resource
        }
        
        // data 字段的 json 中有一个 "appId" 字段，值应当与表结构中的 appId 字段值一致
        // 要解包的 Resource 类型的 type 必须与表结构中 type 的类型相同
        var isValid: Bool {
            T.type == type && data.appId == appId
        }
        
        func fill() -> Self {
            self.$privileges.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<__SDBM.AnyResource>
    }
}

import ResourceDefine

extension AnyResource {
    var dbInstance: __SDBM.AnyResource {
        let new = __SDBM.AnyResource()
        new.id = UUID()
        new.appId = self.appId
        new.type = self.type
        new.data = self.json
        return new
    }
}
