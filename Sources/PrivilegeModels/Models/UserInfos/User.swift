import Foundation
import PrivilegeModule

/// 数据库表 users 的映射类型
/// 记录所有已注册的用户

public extension __SDBM {
    final class User: PGModel, @unchecked Sendable {
        public static let name: String = "users"
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let email = PGField("email", .string)                       .required.unique
            let hashedPassword = PGField("hashed_password", .string)    .required
            let key = PGField("key", .data)                             .required
            let salt = PGField("salt", .data)                           .required
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public static let fields = Fields()
        
        @ID(key: .id)                               public var id: UUID?
        
        @Field(fields.email)                        package var email: String
        @Field(fields.hashedPassword)               package var hashedPassword: String
        @Field(fields.key)                          package var key: Data
        @Field(fields.salt)                         package var salt: Data
        
        @OptionalChild(for: \.$user)                package var token: Token!
        
        @Siblings(
            through: UserGroupPivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                           package var groups: [Group]
        @Siblings(
            through: UserRolePivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                           package var roles: [Role]
        @Siblings(
            through: UserDomainPivot.self,
            from: \.$primaryModel,
            to: \.$secondaryModel
        )                                           package var domains: [Domain]
        
        @Timestamp(fields.createdAt, on: .create)   package var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)   package var updatedAt: Date!
        
        public init() {}
        
        package func fill() -> Self {
            self.$groups.fromId = self.id
            self.$roles.fromId = self.id
            self.$domains.fromId = self.id
            return self
        }
        
        public typealias MIG = DefaultMIG<User>
    }
}
