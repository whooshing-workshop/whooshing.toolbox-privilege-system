import PgSQL
import Foundation
import Policy
import Fluent

/// 数据库表 users 的映射类型
/// 记录所有已注册的用户

public final class User: PGModel, @unchecked Sendable {
    public static let name: String = "users"
    
    public struct Fields: PGFields {
        let id = PGField("id", .uuid)                               .primary
        let email = PGField("email", .string)                       .required.unique
        let hashedPasswd = PGField("hashed_passwd", .string)        .required
        let key = PGField("key", .data)                             .required
        let salt = PGField("salt", .data)                           .required
        let createdAt = PGField("created_at", .datetime)            .required
        let updatedAt = PGField("updated_at", .datetime)            .required
        
        public init() {}
    }
    
    public static let fields = Fields()
    
    @ID(key: .id)                               public var id: UUID?
    
    @Field(fields.email)                        var email: String
    @Field(fields.hashedPasswd)                 var hashedPasswd: String
    @Field(fields.key)                          var key: Data
    @Field(fields.salt)                         var salt: Data
    
    @OptionalChild(for: \Token.$user)           var token: Token!
    
    @Siblings(
        through: UserGroupPivot.self,
        from: \.$user,
        to: \.$group
    )                                           var groups: [UGroup]
    @Siblings(
        through: UserRolePivot.self,
        from: \.$primaryModel,
        to: \.$secondaryModel
    )                                           var roles: [Role]
    @Siblings(
        through: UserDomainPivot.self,
        from: \.$primaryModel,
        to: \.$secondaryModel
    )                                           var domains: [Domain]
    
    @Timestamp(fields.createdAt, on: .create)   var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)   var updatedAt: Date!
    
    public init() {}
    
    func fill() -> Self {
        self.$groups.fromId = self.id
        self.$roles.fromId = self.id
        self.$domains.fromId = self.id
        return self
    }
    
    public typealias MIG = DefaultMIG<User>
}

extension User: Hashable {
    public static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id &&
        lhs.email == rhs.email &&
        lhs.hashedPasswd == rhs.hashedPasswd &&
        lhs.key == rhs.key &&
        lhs.salt == rhs.salt &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(email)
        hasher.combine(hashedPasswd)
        hasher.combine(key)
        hasher.combine(salt)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
}
