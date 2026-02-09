import PgSQL
import Fluent
import Foundation
import Policy

public extension PrivilegeModule {
    final class Privilege: PGModel, @unchecked Sendable {
        
        public static var name: String { "privileges" }
        
        public struct Fields: PGFields {
            public let id = PGField("id", .int64)                           .primary
            public let name = PGField("name", .string)
            public let description = PGField("description", .string)
            public let createdAt = PGField("create_at", .string)            .required
            public let updateAt = PGField("update_at", .string)             .required
            
            public init() {}
        }
        
        public let fields = Fields()
        
        @ID(custom: fields.id.key)                      public var id: Int64?
        
        @Field(fields.name)                             public var name: String?
        @Field(fields.description)                      public var description: String?
        
        @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
        @Timestamp(fields.updateAt, on: .update)        public var updatedAt: Date!
        
        @Children(
            for: \PrivilegePolicy.$parent
        )                                               var policies: [PrivilegePolicy]
        
        @Siblings(
            through: PrivilegeResourcePivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                               var resources: [AnyResource]
        
        public init() { }
        
        public typealias MIG = DefaultMIG<Privilege>
    }

}
