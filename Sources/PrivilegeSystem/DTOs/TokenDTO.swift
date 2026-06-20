import Foundation
import PrivilegeModule

public struct Token: DTO.Model, Codable {
    public let credential: String
    public let tokenEncrypted: Data
    
    public static let logName: String = "Token"
    
    public init(
        credential: String,
        tokenEncrypted: Data
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
    
    init(
        id: UUID? = nil,
        for userId: UUID,
        credential: String = Crypto.randomDataGenerate(length: 16).base64EncodedString(),
        token: String = Crypto.Symm.makeKey().data.base64EncodedString(),
        valid: Bool = true,
        expireAfter: Int = 7 * 24 * 60      // 7 days, minute as unit
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
    func raw() -> SQLModel {
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

public extension QToken {
    func toPrepare() -> Res<Token, PrivilegeSystem.Errcase> {
        .init { () throws(PrivilegeSystem.Errcase.ErrType) in
            let keyData = try required(throws: PrivilegeSystem.Errcase.tokenDTOFailed, "密钥字节解析失败", category: .external) {
                try Base64String(self.token).dataRes.get()
            }
            let key = Crypto.Symm.Key.new(data: keyData)
            return .init(
                credential: self.credential,
                tokenEncrypted: try required(throws: PrivilegeSystem.Errcase.tokenDTOFailed, "密钥加密失败", category: .external) {
                    try Crypto.Symm.encrypt(key, key: key).get()
                }
            )
        }
    }
}

extension QToken: __Queried {
    package typealias Failure = PrivilegeSystem.Errcase
    public static func make(from model: __SDBM.Token) -> Res<Self, PrivilegeSystem.Errcase> {
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
    public typealias ErrorType = PrivilegeSystem.Errcase
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
