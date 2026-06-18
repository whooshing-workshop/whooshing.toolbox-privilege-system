import PgSQL
import Fluent
import Foundation
import Policy
import DTOBuilder

public extension PM.__DBM {
    final class Privilege: PGModel, @unchecked Sendable {
        
        public static var name: String { "privileges" }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let name = PGField("name", .string)
            let description = PGField("description", .string)
            let policy = PGField("policy", .string)                     .required
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public let fields = Fields()
        
        @ID(key: .id)                                   public var id: UUID?
        
        @Field(fields.name)                             var name: String?
        @Field(fields.description)                      var description: String?
        @Field(fields.policy)                           var policy: String
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
        
        @Siblings(
            through: PrivilegeAnyResourcePivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                               var resources: [__SDBM.AnyResource]
        
        public init() { }
        
        // 使用 Fluent 批量创建 Model 后([dbModels].create(on: db))，这些批量创建的 Models 的 sibilings 都会失效，直接使用会触发断言崩溃，因此需要显式指定其 fromId"
        func fill() -> Self {
            self.$resources.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<Privilege>
    }
}

extension PM.__DBM.Privilege: PolicyType {
    public typealias DTOModel = PrivilegeModule.QPrivilege
    public typealias Model = PrivilegeModule.__DBM.Privilege
    public static var namePrefix: String { "privilege" }
    public static var typeId: String { "privilege" }
}
