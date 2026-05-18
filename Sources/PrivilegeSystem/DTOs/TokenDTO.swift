import Vapor
import Fluent
import ErrorHandle
import Cryptos
import PrivilegeModule
import DataConvertable
import Query
import LoggingAdvanced
import AnyCodable

package typealias TokenModel = Token

public typealias PToken = DTO.Token<DTO.Prepare>
public typealias QToken = DTO.Token<DTO.Queried>

public extension DTO {
    struct Token<T: Status>: DTOModel, Sendable, Hashable {
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
        let isQueried = T.self == DTO.Queried.self
        
        let credPrefix = String(self.credential.prefix(4))
        let credDisplay = "\(credPrefix)****"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "user_id": AnyCodable(isQueried ? "\(self.userId)" : nil),
            "credential": AnyCodable(credDisplay),
            "token": AnyCodable("[PROTECTED_KEY]"),
            "token_encrypted": AnyCodable("[BINARY_DATA]"),
            "valid": AnyCodable(isQueried ? self.valid : nil),
            "expire_after": AnyCodable(self.expireAfter),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
}

extension DTO.Token where T == DTO.Prepare {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(credential)
        hasher.combine(tokenEncrypted)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.credential == rhs.credential &&
        lhs.tokenEncrypted == rhs.tokenEncrypted
    }
}

extension DTO.Token where T == DTO.Queried {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(credential)
        hasher.combine(id)
        hasher.combine(token)
        hasher.combine(userId)
        hasher.combine(valid)
        hasher.combine(expireAfter)
        hasher.combine(createdAt)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.credential == rhs.credential &&
        lhs.id == rhs.id &&
        lhs.token == rhs.token &&
        lhs.userId == rhs.userId &&
        lhs.valid == rhs.valid &&
        lhs.expireAfter == rhs.expireAfter &&
        lhs.createdAt == rhs.createdAt
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
