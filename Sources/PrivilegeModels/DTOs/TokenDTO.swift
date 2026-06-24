import Vapor
import Foundation
import PrivilegeModule

/// 用于用户通过 API Client 验证时使用的模型，其加密机制为 [密钥加密[密钥 hash]] + [明文凭据]
/// 用于通讯通道未加密的情况
public struct EncryptedToken: DTO.Model, Codable {
    public let credential: String
    public let tokenEncrypted: String
    
    public static let logName: String = "EncryptedToken"
    
    public init(
        credential: String,
        tokenEncrypted: String
    ) {
        self.credential = credential
        self.tokenEncrypted = tokenEncrypted
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .credential: .init(obj: self.credential)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.credential] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case credential
        case tokenEncrypted = "token_encrypted"
    }
    
    /// 从服务器返回的 QToken 详细内容转为可参与服务验证的安全 Token
    /// 加密机制为 [密钥加密[密钥 hash]] + [明文凭据]
    public static func make(from token: QToken) -> Res<Self, PrivilegeModuleExtended.Errcase> {
        .init { () throws(PrivilegeModuleExtended.Errcase.ErrType) in
            let keyData = try required(throws: PrivilegeModuleExtended.Errcase.tokenDTOFailed, "用户口令字节解析失败", category: .external(suggestions: ["请提供正确的登陆口令"])) {
                try Base64String(token.token).dataRes.get()
            }
            let key = Crypto.Symm.Key.new(data: keyData)
            let hashedKey = Crypto.hash(keyData)
            return .init(
                credential: token.credential,
                tokenEncrypted: try required(throws: PrivilegeModuleExtended.Errcase.tokenDTOFailed, "口令加密失败", category: .internal) {
                    try Crypto.Symm.encrypt(hashedKey, key: key).get()
                }.base64EncodedString()
            )
        }
    }
}

/// 用于用户通过主服务器验证时使用的模型，其加密机制为 [密钥 hash] + [明文凭据]
/// 仅用于通讯通道已经可靠加密的情况
public struct AuthorizationToken: DTO.Model, Codable {
    public let credential: String
    public let tokenHashed: String
    
    public static let logName: String = "AuthorizationToken"
    
    public init(
        credential: String,
        tokenHashed: String
    ) {
        self.credential = credential
        self.tokenHashed = tokenHashed
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .credential: .init(obj: self.credential)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.credential] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case credential
        case tokenHashed = "token_hashed"
    }
    
    /// 从服务器返回的 QToken 详细内容转为可参与身份验证的安全 Token
    /// 加密机制为 [密钥 hash] + [明文凭据]
    public static func make(from token: QToken) -> Res<Self, PrivilegeModuleExtended.Errcase> {
        .init { () throws(PrivilegeModuleExtended.Errcase.ErrType) in
            let keyData = try required(throws: PrivilegeModuleExtended.Errcase.tokenDTOFailed, "用户口令字节解析失败", category: .external(suggestions: ["请提供正确的登陆口令"])) {
                try Base64String(token.token).dataRes.get()
            }
            return .init(
                credential: token.credential,
                tokenHashed: Crypto.hash(keyData).base64EncodedString()
            )
        }
    }
}

public struct PToken: DTO.Prepare {
    public typealias QueriedModel = QToken
    public let id: UUID?
    public let credential: String
    public var token: String {
        guard let t = __token else {
            fatalError("受保护属性，不允许日志打印或进行网络通讯")
        }
        return t
    }
    private let __token: String?
    public let userId: UUID
    public let valid: Bool
    public let expireAfter: Int
    
    public static let logName: String = "PToken"
    
    package init(
        id: UUID? = nil,
        for userId: UUID,
        credential: String = Crypto.randomDataGenerate(length: 16).base64EncodedString(),   // credential 为 16 字节的随机数据
        token: String = Crypto.Symm.makeKey().data.base64EncodedString(),                   // Token 其实是一个对称密钥转为 base64 string
        valid: Bool = true,
        expireAfter: Int = 7 * 24 * 60                                                      // 7 天，以分钟为单位
    ) {
        self.id = id
        self.credential = credential
        self.__token = token
        self.userId = userId
        self.valid = valid
        self.expireAfter = expireAfter
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .id: .init(obj: self.id),
        .credential: .init(obj: self.credential),
        .userId: .init(obj: self.userId),
        .valid: .init(obj: self.valid),
        .expireAfter: .init(obj: self.expireAfter)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .credential, .userId] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case id
        case credential
        case userId = "user_id"
        case valid
        case expireAfter = "expire_after"
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id)
        self.credential = try container.decode(String.self, forKey: .credential)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.valid = try container.decode(Bool.self, forKey: .valid)
        self.expireAfter = try container.decode(Int.self, forKey: .expireAfter)
        self.__token = nil  // 通过编解码后赋为空值，保护属性
    }
    
    // 不编码 token 保护属性
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.id, forKey: .id)
        try container.encode(self.credential, forKey: .credential)
        try container.encode(self.userId, forKey: .userId)
        try container.encode(self.valid, forKey: .valid)
        try container.encode(self.expireAfter, forKey: .expireAfter)
    }
}

public struct QToken: DTO.Queried {
    public typealias PrepareModel = PToken
    public let id: UUID
    public let credential: String
    public var token: String {
        guard let t = __token else {
            fatalError("受保护属性，不允许日志打印或进行网络通讯")
        }
        return t
    }
    public let valid: Bool
    public let expireAfter: Int
    public let createdAt: Date
    
    @Super public var user: QUser
    
    private let __token: String?
    
    public static let logName: String = "QToken"
    
    package let __m: __SDBM.Token?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .credential: .init(obj: self.credential),
        .id: .init(obj: self.id),
        .userId: .init(obj: self.$user.id),
        .valid: .init(obj: self.valid),
        .expireAfter: .init(obj: self.expireAfter),
        .createdAt: .init(obj: self.createdAt),
        
        .user: .init(obj: self.$user)
    ]}
    
    public var summaryKeys: [CodingKeys] { [.id, .credential, .userId] }
    
    public enum CodingKeys: String, DTO.CodingKey {
        case credential
        case token
        case id
        case userId = "user_id"
        case valid
        case expireAfter = "expire_after"
        case createdAt = "created_at"
        
        case user
    }
    
    init(
        id: UUID,
        credential: String,
        token: String?,
        userId: UUID,
        valid: Bool,
        expireAfter: Int,
        createdAt: Date,
        model: SQLModel?
    ) {
        self.credential = credential
        self.id = id
        self.__token = token
        self.valid = valid
        self.expireAfter = expireAfter
        self.createdAt = createdAt
        self.__m = model
        
        self.$user.id = userId
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = Self.init(
            id: try container.decode(UUID.self, forKey: .id),
            credential: try container.decode(String.self, forKey: .credential),
            token: try container.decode(String.self, forKey: .token),
            userId: try container.decode(UUID.self, forKey: .userId),
            valid: try container.decode(Bool.self, forKey: .valid),
            expireAfter: try container.decode(Int.self, forKey: .expireAfter),
            createdAt: try container.decode(DateWrapper.self, forKey: .createdAt).date,
            model: nil
        )
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.credential, forKey: .credential)
        try container.encode(self.token, forKey: .token)
        try container.encode(self.$user.id, forKey: .userId)
        try container.encode(self.valid, forKey: .valid)
        try container.encode(self.expireAfter, forKey: .expireAfter)
        try container.encode(DateWrapper(self.createdAt), forKey: .createdAt)
    }
}

extension PToken: __Prepare {
    package func raw() -> SQLModel {
        let token = SQLModel()
        token.id = id
        token.$user.id = userId
        token.credential = credential
        token.token = self.token
        token.expireAfter = expireAfter
        token.valid = valid
        return token
    }
}

extension QToken: __Queried {
    package typealias Failure = PrivilegeModuleExtended.Errcase
    public static func make(from model: __SDBM.Token) -> Res<Self, PrivilegeModuleExtended.Errcase> {
        .init(throws: .tokenDTOFailed, category: .internal) {
            try Self.init(
                id: model.requireID(),
                credential: model.credential,
                token: model.token,
                userId: model.$user.id,
                valid: model.valid,
                expireAfter: model.expireAfter,
                createdAt: model.createdAt,
                model: model
            )
        }
    }
}

extension QToken: Query.Queriable {
    public typealias Model = __SDBM.Token
    public typealias ErrorType = PrivilegeModuleExtended.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        Self.idKey: \.$id,
        \.credential: \.$credential,
        \.id: \.$id,
        \.token: \.$token,
        \.$user.id: \.$user.$id,
        \.valid: \.$valid,
        \.expireAfter: \.$expireAfter,
        \.createdAt: \.$createdAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$credential)
            .field(Model.self, \.$id)
            .field(Model.self, \.$token)
            .field(Model.self, \.$user.$id)
            .field(Model.self, \.$valid)
            .field(Model.self, \.$expireAfter)
            .field(Model.self, \.$createdAt)
    }
}
