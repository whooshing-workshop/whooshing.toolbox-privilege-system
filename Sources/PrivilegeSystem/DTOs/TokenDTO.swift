import Vapor
import Fluent
import ErrorHandle
import Cryptos
import PrivilegeModule
import DataConvertable
import Query
import Policy
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public struct Token: DTO.Model {
    public let credential: String
    public let tokenEncrypted: Data
    
    public init(
        credential: String,
        tokenEncrypted: Data
    ) {
        self.credential = credential
        self.tokenEncrypted = tokenEncrypted
    }
    
    public var maps: [CodingKeys: AnyCodable] {[
        .credential: .init(self.credential),
        .tokenEncrypted: .init("<Protected>")
    ]}
    
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
    
    public var maps: [CodingKeys : AnyCodable] {[
        .id: .init(self.id),
        .credential: .init(self.credential),
        .userId: .init(self.userId),
        .valid: .init(self.valid),
        .expireAfter: .init(self.expireAfter)
    ]}
    
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
    public let userId: UUID
    public let valid: Bool
    public let expireAfter: Int
    public let createdAt: Date
    
    private let __token: String?
    
    package let __m: __SDBM.Token?
    package static let idProperty: KeyPath<SQLModel, IDProperty<SQLModel, UUID>> = \.$id
    
    public var maps: [CodingKeys : AnyCodable] {[
        .credential: .init(self.credential),
        .id: .init(self.id),
        .userId: .init(self.userId),
        .valid: .init(self.valid),
        .expireAfter: .init(self.expireAfter),
        .createdAt: .init(self.createdAt)
    ]}
    
    public enum CodingKeys: String, DTO.CodingKey {
        case credential
        case id
        case userId = "user_id"
        case valid
        case expireAfter = "expire_after"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID,
        credential: String,
        token: String,
        userId: UUID,
        valid: Bool,
        expireAfter: Int,
        createdAt: Date,
        model: SQLModel?
    ) {
        self.credential = credential
        self.id = id
        self.__token = token
        self.userId = userId
        self.valid = valid
        self.expireAfter = expireAfter
        self.createdAt = createdAt
        self.__m = model
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.credential = try container.decode(String.self, forKey: .credential)
        self.userId = try container.decode(UUID.self, forKey: .userId)
        self.valid = try container.decode(Bool.self, forKey: .valid)
        self.expireAfter = try container.decode(Int.self, forKey: .expireAfter)
        self.createdAt = try container.decode(DateWrapper.self, forKey: .createdAt).date
        self.__token = nil  // 通过编解码后赋为空值，保护属性
        self.__m = nil
    }
    
    // 不编码 token 保护属性
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.credential, forKey: .credential)
        try container.encode(self.userId, forKey: .userId)
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
        \.credential: \.$credential,
        \.id: \.$id,
        \.token: \.$token,
        \.userId: \.$user.$id,
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
