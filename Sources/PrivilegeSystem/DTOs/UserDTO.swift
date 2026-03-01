import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import Policy
import PrivilegeModule

typealias UserModel = User

public extension DTO {
    struct User<T: Status>: Sendable {
        public let email: String
        
        @Protect public internal(set) var hashedPasswd: String
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
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
    
    init(email: String, hashedPasswd: Data) {
        self = Self.init(email: email, hashedPasswd: hashedPasswd.base64EncodedString())
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
            n.$updatedAt = model.updatedAt
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
    enum CodingKeys: String, CodingKey {
        case email
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
        try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
    }
}

//import PgSQL
//import Fluent
//
//public extension DTO.User {
//    struct Querier {
//        private let builder: QueryBuilder<User>
//        
//        internal init(db: PGDatabase) {
//            self.builder = UserModel.query(on: db)
//        }
//        
//        private let pathMap: [PartialKeyPath<DTO.User<DTO.Queried>>: PartialKeyPath<User>] = [
//            \.email: \.$email,
//            \.id: \.$id
//        ]
//        
//        /// 核心过滤方法：支持 DTO KeyPath
//        package func filter<V: Encodable>(
//            _ dtoPath: KeyPath<DTO.User<DTO.Queried>, V>,
//            _ op: DatabaseQuery.Filter.Method,
//            _ value: V
//        ) -> Self {
//            // 查找映射关系
//            guard let modelPath = pathMap[dtoPath] as? KeyPath<User, IDProperty<User, User.IDValue>> else {
//                // 如果没映射，说明这个字段不允许外部查询
//                return self
//            }
//            
//            // 执行真正的 Fluent 过滤
//            builder.filter(modelPath, op, value as! User.IDValue)
//            return self
//        }
//
//        package func all() async throws -> [DTO.User<DTO.Queried>] {
//            let models = try await builder.all()
//            return models.map { try! DTO.User<DTO.Queried>.make(from: $0).get() }
//        }
//    }
//}
