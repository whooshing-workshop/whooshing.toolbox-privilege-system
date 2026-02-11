import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import PrivilegeModule

typealias UserModel = User

public extension DTO {
    struct User<T: Status>: Sendable {
        public let email: String
        @Protect() public var hashedPasswd: String
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        typealias AssociatedModel = UserModel
        private let m: AssociatedModel?
        
        init(
            _email: String,
            _model: AssociatedModel?
        ) {
            self.email = _email
            self.m = _model
        }
    }
}

public extension DTO.User where T == DTO.Prepare {
    // 这里的 hashedPasswd 只有第一层密码加密，存入数据库之前要进行第二次加密
    init(email: String, hashedPasswd: String) {
        self = Self.init(_email: email, _model: nil)
        self.hashedPasswd = hashedPasswd
    }
}

extension DTO.User where T == DTO.Queried {
    var model: User {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: User) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, "用户 ID 获取失败", category: .internal) {
            var n = Self.init(
                _email: model.email,
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updateAt
            return n
        }
    }
}

extension DTO.User where T == DTO.Prepare {
    func raw() -> Res<User, PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, category: .internal) {
            let user = User()
            user.email = email
            // 为用户创建一个用户加密密钥
            user.key = Crypto.Symm.makeKey().data
            (user.salt, user.hashedPasswd) = try Self.doubleEncode(hashedPasswd: hashedPasswd).get()
            return user
        }
    }
    
    static func doubleEncode(hashedPasswd: String) -> Res<(salt: Data, passwdEncoded: String), PrivilegeSystem.Errcase> {
        .init(throws: .userDTOFailed, category: .internal) {
            // 生成随即盐
            let salt = Crypto.randomDataGenerate()
            // 对用户密码进行第二重加盐哈希
            let passwd = try required(throws: PrivilegeSystem.Errcase.userRegisterFailed, "对密码进行二次哈希时失败", category: .internal) {
                try Crypto.hash(Base64String(hashedPasswd).dataRes.get() + salt)
            }
            
            return (salt, passwd.base64EncodedString())
        }
    }
}

extension User: ModelAuthenticatable {
    package static let usernameKey: KeyPath<User, Field<String>> = \User.$email
    package static let passwordHashKey: KeyPath<User, Field<String>> = \User.$hashedPasswd
    
    package func verify(password: String) throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        // 客户端请求所提供的密码是 其对其用户明文密码进行单次哈希的结果
        let passwd = try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .external) {
            try Base64String(password).dataRes.get()
        }
        // 对客户端密码设置后置盐，并再次哈希
        let hashed = Crypto.hash(passwd + self.salt)
        return try required(throws: PrivilegeSystem.Errcase.userAuthenticateFailed, "对密码进行 Base64 转换失败", category: .external) {
            try hashed == Base64String(self.hashedPasswd).dataRes.get()
        }
    }
}

extension DTO.User: Encodable where T == DTO.Queried {
    enum CodingKeys: CodingKey {
        case email
        case id
        case createdAt
        case updateAt
    }
}
