import Vapor
import Fluent
import ErrorHandle
import Cryptos

typealias TokenModel = Token

public extension DTO {
    struct Token<T: Status>: Sendable {
        public let credential: String
        public let token: String
        public let userId: UUID
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var valid: Bool
        @Passive() public internal(set) var expireAfter: Int
        @Passive() public internal(set) var createdAt: Date
        
        typealias AssociatedModel = TokenModel
        private let m: AssociatedModel?
        
        init(
            _credential: String,
            _token: String,
            _userId: UUID,
            _model: AssociatedModel?
        ) {
            self.credential = _credential
            self.token = _token
            self.userId = _userId
            self.m = _model
        }
    }
}

extension DTO.Token where T == DTO.Prepare {
    init(for userId: UUID) {
        self = Self.init(
            _credential: Crypto.randomDataGenerate(length: 16).base64EncodedString(),
            _token: Crypto.Symm.makeKey().data.base64EncodedString(),
            _userId: userId,
            _model: nil
        )
        self.expireAfter = 7 * 24 * 60      // 7 days, minute as unit
    }
}

extension DTO.Token where T == DTO.Queried {
    var model: Token {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: Token) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .tokenDTOFailed, category: .internal) {
            var n = Self.init(
                _credential: model.credential,
                _token: model.token,
                _userId: model.$user.id,
                _model: model
            )
            n.$id = try model.requireID()
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
        return token
    }
}
