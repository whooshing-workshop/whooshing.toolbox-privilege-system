import Vapor
import Fluent
import ErrorHandle
import Cryptos
import PrivilegeModule
import DataConvertable
import Query
import LoggingAdvanced

typealias TokenModel = Token

public typealias PToken = DTO.Token<DTO.Prepare>
public typealias QToken = DTO.Token<DTO.Queried>

public extension DTO {
    struct Token<T: Status>: Sendable {
        public let credential: String
        
        @Protect public internal(set) var tokenEncrypted: Data
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var token: String
        @Passive public internal(set) var userId: UUID
        @Passive public internal(set) var valid: Bool
        @Passive public internal(set) var expireAfter: Int
        @Passive public internal(set) var createdAt: Date
        
        typealias AssociatedModel = TokenModel
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
        // 1. 状态标签
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        // 2. 状态分流判断
        let isQueried = T.self == DTO.Queried.self
        
        // 3. 字段安全提取
        // 注意：credential 虽然是 public，但通常不建议在日志中全显，这里保留前 4 位
        let credPrefix = String(self.credential.prefix(4))
        let credDisplay = "\(credPrefix)****"
        
        let idVal = isQueried ? "\"\(self.id)\"" : "null"
        let userIdVal = isQueried ? "\"\(self.userId)\"" : "null"
        let validVal = isQueried ? "\(self.valid)" : "null"
        let expireVal = isQueried ? "\(self.expireAfter)" : "\(self.expireAfter)" // Prepare 阶段已有默认值
        let createdVal = isQueried ? "\"\(self.createdAt)\"" : "null"

        return """
        {
            "status": "\(statusLabel)",
            "data": {
                "id": \(idVal),
                "user_id": \(userIdVal),
                "credential": "\(credDisplay)",
                "token": "[PROTECTED_KEY]",
                "token_encrypted": "[BINARY_DATA]",
                "valid": \(validVal),
                "expire_after": \(expireVal),
                "created_at": \(createdVal)
            }
        }
        """
    }
}
