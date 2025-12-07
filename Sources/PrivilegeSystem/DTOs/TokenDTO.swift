import Vapor
import Fluent
import ErrorHandle
import Cryptos

public extension DTO {
    struct Token<T: Status>: Sendable {
        public let credential: String
        public let token: String
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var userId: UUID
        @Passive() public internal(set) var valid: Bool
        @Passive() public internal(set) var expireAfter: Int
        @Passive() public internal(set) var createdAt: Date
    }
}

extension DTO.Token where T == DTO.Prepare {
    init(for userId: User.IDValue) {
        self.credential = Crypto.randomDataGenerate(length: 16).base64EncodedString()
        self.token = Crypto.Symm.makeKey().data.base64EncodedString()
        self.userId = userId
        self.expireAfter = 7 * 24 * 60      // 7 days, minute as unit
    }
}

extension DTO.Token where T == DTO.Queried {
    static func make(from model: Token) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, "Token ID 获取失败", category: .internel) {
            var n = Self.init(
                credential: model.credential,
                token: model.token
            )
            n.$id = try model.requireID()
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
        var token = Token()
        token.$user.id = userId
        token.credential = credential
        token.token = self.token
        token.expireAfter = expireAfter
        return token
    }
}
