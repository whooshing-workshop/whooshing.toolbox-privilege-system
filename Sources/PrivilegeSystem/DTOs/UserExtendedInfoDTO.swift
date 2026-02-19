import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import Collections
import PrivilegeModule

public extension DTO {
    protocol UserInfoModel: Sendable {
        associatedtype Value: Sendable & Codable
        associatedtype Model: UserInfoExtends.Model
        static var description: String { get }
    }
    
    struct UserExtendedInfo<T: UserInfoModel, G: Status>: Sendable {
        public let value: T.Value
        public let order: Int16
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var userInfoId: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updatedAt: Date
        
        typealias AssociatedModel = UserModel.Info.Extended<T.Model>
        private let m: AssociatedModel?
        
        init(
            _value: T.Value,
            _order: Int16,
            _description: String?,
            _model: AssociatedModel?
        ) {
            self.value = _value
            self.order = _order
            self.description = _description
            self.m = _model
        }
    }
    
    struct Address: UserInfoModel {
        public typealias Value = String
        public typealias Model = UserInfoExtends.Address
        public static let description = "地址"
    }
    
    struct AlternateEmail: UserInfoModel {
        public typealias Value = String
        public typealias Model = UserInfoExtends.AlternateEmail
        public static let description = "次要邮箱"
    }
    
    struct Phone: UserInfoModel {
        public typealias Value = String
        public typealias Model = UserInfoExtends.Phone
        public static let description = "次要手机号"
    }
}

public extension DTO.UserExtendedInfo where G == DTO.Prepare {
    init(value: T.Value, order: Int16, description: String?) {
        self = Self.init(
            _value: value,
            _order: order,
            _description: description,
            _model: nil
        )
    }
}

extension DTO.UserExtendedInfo where G == DTO.Queried, T.Value == String {
    var model: User.Info.Extended<T.Model> {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: User.Info.Extended<T.Model>) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internal) {
            var n = Self.init(
                _value: model.value,     // 暂时使用强制解包，因为目前用户 Info Value 字段均为 String
                _order: model.order,
                _description: model.description,
                _model: model
            )
            n.$id = try model.requireID()
            n.$userInfoId = model.$userInfo.id
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
            return n
        }
    }
}

extension DTO.UserExtendedInfo where G == DTO.Prepare, T.Value == String {
    func raw(for userInfoId: UUID) -> User.Info.Extended<T.Model> {
        let info = User.Info.Extended<T.Model>()
        info.$userInfo.id = userInfoId
        info.value = value
        info.order = order
        info.description = description
        return info
    }
}

public extension DTO.UserExtendedInfo where T.Value == String, G == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let userInfoId: UUID
        package var id: UUID { userInfoId }
        
        package private(set) var updates: OrderedDictionary<
            PartialKeyPath<DTO.UserExtendedInfo<T, DTO.Prepare>>,
            (QueryBuilder<User.Info.Extended<T.Model>>, DTO.UserExtendedInfo<T, DTO.Queried>?) throws -> QueryBuilder<User.Info.Extended<T.Model>>
        > = [:]
        package private(set) var needsPeek = false
        
        public init(userInfoId: UUID) {
            self.userInfoId = userInfoId
        }
    }
}

extension DTO.UserExtendedInfo.Updater: DTOUpdater {}

public extension DTO.UserExtendedInfo.Updater {
    mutating
    func update(value: @escaping @autoclosure () throws -> T.Value) {
        updates[\.value] = { builder, _ in
            builder.set(\.$value, to: try value())
        }
    }
    
    mutating
    func update(order: @escaping @autoclosure () throws -> Int16) {
        updates[\.order] = { builder, _ in
            builder.set(\.$order, to: try order())
        }
    }
    
    mutating
    func update(description: @escaping @autoclosure () throws -> String?) {
        updates[\.description] = { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
}

public extension DTO.UserExtendedInfo.Updater {
    mutating
    func update(value: @escaping (DTO.UserExtendedInfo<T, DTO.Queried>) throws -> T.Value) {
        needsPeek = true
        updates[\.value] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$value, to: try value(q))
        }
    }
    
    mutating
    func update(order: @escaping (DTO.UserExtendedInfo<T, DTO.Queried>) throws -> Int16) {
        needsPeek = true
        updates[\.order] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$order, to: try order(q))
        }
    }
    
    mutating
    func update(description: @escaping (DTO.UserExtendedInfo<T, DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.description] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}

extension DTO.UserExtendedInfo: Encodable where G == DTO.Queried {
    enum CodingKeys: CodingKey {
        case value
        case order
        case description
        case id
        case userInfoId
        case createdAt
        case updatedAt
    }
}
