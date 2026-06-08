import Vapor
import Fluent
import ErrorHandle
import Cryptos
import PrivilegeModule
import DataConvertable
import Query
import LoggingAdvanced
import AnyCodable
import ResourceMacros

package typealias TokenModel = Token

public typealias PToken = DTO.Token<DTO.Prepare>
public typealias QToken = DTO.Token<DTO.Queried>

public extension DTO {
    struct Token<T: Status>: DTOModel, Sendable {
        public let credential: String
        
        @Protect public internal(set) var tokenEncrypted: Data
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var token: String
        @Passive public internal(set) var userId: UUID
        @Passive public internal(set) var valid: Bool
        @Passive public internal(set) var expireAfter: Int
        @Passive public internal(set) var createdAt: Date
        
        package typealias AssociatedModel = TokenModel
        private let m: AssociatedModel?
        
        init(
            _credential: String,
            _model: AssociatedModel?
        ) {
            self.credential = _credential
            self.m = _model
            self.expireAfter = 7 * 24 * 60      // 7 days, minute as unit
        }
    }
}

public extension DTO.Token where T == DTO.Prepare {
    init(
        credential: String,
        tokenEncrypted: Data
    ) {
        self = Self.init(_credential: credential, _model: nil)
        self.tokenEncrypted = tokenEncrypted
    }
}

public extension DTO.Token where T == DTO.Queried {
    func toPrepare() -> Res<DTO.Token<DTO.Prepare>, PrivilegeSystem.Errcase> {
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

extension DTO.Token where T == DTO.Prepare {
    init(for userId: UUID) throws(PrivilegeSystem.Errcase.ErrType) {
        let tokenKey = Crypto.Symm.makeKey()
        self = Self.init(
            _credential: Crypto.randomDataGenerate(length: 16).base64EncodedString(),
            _model: nil
        )
        
        self.token = tokenKey.data.base64EncodedString()
        self.userId = userId
    }
}

extension DTO.Token where T == DTO.Queried {
    var model: Token {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: Token) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .tokenDTOFailed, category: .internal) {
            var n = Self.init(
                _credential: model.credential,
                _model: model
            )
            n.$id = try model.requireID()
            n.$token = model.token
            n.$userId = model.$user.id
            n.$valid = model.valid
            n.$expireAfter = model.expireAfter
            n.$createdAt = model.createdAt
            return n
        }
    }
}

extension DTO.Token where T == DTO.Prepare {
    func raw() -> Token {
        let token = Token()
        token.$user.id = userId
        token.credential = credential
        token.token = self.token
        token.expireAfter = expireAfter
        token.valid = true
        return token
    }
}

extension DTO.Token: Query.Queriable where T == DTO.Queried {
    public typealias Model = Token
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

extension DTO.Token: CustomStringConvertible, Loggerable {
    public var description: String {
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable]
        if T.self == DTO.Prepare.self {
            data = [
                "credential": AnyCodable(credential),
                "token": AnyCodable("[PROTECTED_KEY]"),
                "token_encrypted": AnyCodable("[BINARY_DATA]"),
                "expire_after": AnyCodable(self.expireAfter)
            ]
        } else {
            data = [
                "id": AnyCodable("\(self.id)"),
                "user_id": AnyCodable("\(self.userId)"),
                "credential": AnyCodable(credential),
                "token": AnyCodable("[PROTECTED_KEY]"),
                "token_encrypted": AnyCodable("[BINARY_DATA]"),
                "valid": AnyCodable(self.valid),
                "expire_after": AnyCodable(self.expireAfter),
                "created_at": AnyCodable("\(self.createdAt)")
            ]
        }

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
    
    public var summaryDescription: String {
        let isQueried = T.self == DTO.Queried.self
        return isQueried ?
            "Token(\(id.shortString), cred:\(credential))" :
            "Token(cred:\(credential))"
    }
}

extension DTO.Token: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(credential)
            hasher.combine(tokenEncrypted)
        } else {
            hasher.combine(credential)
            hasher.combine(id)
            hasher.combine(token)
            hasher.combine(userId)
            hasher.combine(valid)
            hasher.combine(expireAfter)
            hasher.combine(createdAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.credential == rhs.credential &&
            lhs.tokenEncrypted == rhs.tokenEncrypted
        } else {
            lhs.credential == rhs.credential &&
            lhs.id == rhs.id &&
            lhs.token == rhs.token &&
            lhs.userId == rhs.userId &&
            lhs.valid == rhs.valid &&
            lhs.expireAfter == rhs.expireAfter &&
            lhs.createdAt == rhs.createdAt
        }
    }
}

public extension DTO.Token where T == DTO.Prepare {
    func like(_ rhs: QToken) -> Bool {
        self.credential == rhs.credential
    }
}

public extension DTO.Token where T == DTO.Queried {
    func like(_ rhs: PToken) -> Bool {
        self.credential == rhs.credential
    }
}

public extension Collection where Element == PToken {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QToken {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QToken {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PToken {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

extension DTO.Token: Encodable {
    enum CodingKeys: String, CodingKey {
        case credential
        case tokenEncrypted = "token_encrypted"
        case token
        case userId = "user_id"
        case valid
        case expireAfter = "expire_after"
        case id
        case createdAt = "created_at"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(credential, forKey: .credential)
        if T.self == DTO.Queried.self {
            try container.encode(id, forKey: .id)
            try container.encode(token, forKey: .token)
            try container.encode(userId, forKey: .userId)
            try container.encode(valid, forKey: .valid)
            try container.encode(expireAfter, forKey: .expireAfter)
            try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
        }
    }
}
