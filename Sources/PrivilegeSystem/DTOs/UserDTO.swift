import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import Policy
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public struct PUser: DTO.Prepare {
    public typealias QueriedModel = QUser
    public let id: UUID?
    public let email: String
    public let hashedPassword: String
    
    // 这里的 hashedPassword 只有第一层密码加密，存入数据库之前要进行第二次加密
    public init(
        id: UUID? = nil,
        email: String,
        hashedPassword: String
    ) {
        self.id = id
        self.email = email
        self.hashedPassword = hashedPassword
    }
    
    public init(email: String, hashedPassword: Data) {
        self = Self.init(email: email, hashedPassword: hashedPassword.base64EncodedString())
    }
    
    // 不记录 hashed_password 属性
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .email: .init(obj: self.email)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case email
        case hashedPassword = "hashed_password"
    }
}

public struct QUser: DTO.Queried {
    public typealias PrepareModel = PUser
    public let id: UUID
    public let email: String
    public let createdAt: Date
    public let updatedAt: Date
    
    package let __m: __SDBM.User?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .email: .init(obj: self.email),
        .createdAt: .init(obj: self.createdAt),
        .updatedAt: .init(obj: self.updatedAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID,
        email: String,
        createdAt: Date,
        updatedAt: Date,
        model: SQLModel?
    ) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.updatedAt = try container.decode(DateWrapper.self, forKey: .updatedAt).date
        self.__m = nil
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.email, forKey: .email)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
        try container.encode(DateWrapper(self.updatedAt), forKey: .updatedAt)
    }
}

extension PUser: __Prepare {
    func raw() -> Res<SQLModel, PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, category: .internal) {
            let user = SQLModel()
            user.id = id
            user.email = email
            // 为用户创建一个用户加密密钥
            user.key = Crypto.Symm.makeKey().data
            (user.salt, user.hashedPassword) = try Self.doubleEncode(hashedPassword: hashedPassword).get()
            return user
        }
    }
        
    static func doubleEncode(hashedPassword: String) -> Res<(salt: Data, passwdEncoded: String), PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, category: .internal) {
            // 生成随即盐
            let salt = Crypto.randomDataGenerate()
            // 对用户密码进行第二重加盐哈希
            let passwd = try required(throws: PrivilegeSystem.Errcase.userRegisterFailed, "对密码进行二次哈希时失败", category: .internal) {
                try Crypto.hash(Base64String(hashedPassword).dataRes.get() + salt)
            }
            
            return (salt, passwd.base64EncodedString())
        }
    }
}

extension QUser: __Queried {
    public typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: __SDBM.User) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, "用户 ID 获取失败", category: .internal) {
            try Self.init(
                id: model.requireID(),
                email: model.email,
                createdAt: model.createdAt,
                updatedAt: model.updatedAt,
                model: model
            )
        }
    }
}

extension QUser: Query.Queriable {
    public typealias Model = __SDBM.User
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.email: \.$email,
        \.id: \.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$email)
            .field(Model.self, \.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

// MARK: - ModelAuthenticatable

extension __SDBM.User: ModelAuthenticatable {
    public static let usernameKey: KeyPath<__SDBM.User, Field<String>> = \.$email
    public static let passwordHashKey: KeyPath<__SDBM.User, Field<String>> = \.$hashedPassword
    
    public func verify(password: String) throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        // 客户端请求所提供的密码是 其对其用户明文密码进行单次哈希的结果
        let passwd = try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .external) {
            try Base64String(password).dataRes.get()
        }
        // 对客户端密码设置后置盐，并再次哈希
        let hashed = Crypto.hash(passwd + self.salt)
        return try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .external) {
            try hashed == Base64String(self.hashedPassword).dataRes.get()
        }
    }
}
