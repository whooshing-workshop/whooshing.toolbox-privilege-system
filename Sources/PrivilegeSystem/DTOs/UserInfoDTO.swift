import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos

public extension DTO {
    struct UserInfo<T: Status>: Sendable {
        public let userId: UUID
        public let identifier: String
        public let birthday: Date
        public let other: String?
        public let addresses: [UserExtendedInfo<Address, T>]
        public let alternateEmails: [UserExtendedInfo<AlternateEmail, T>]
        public let phones: [UserExtendedInfo<Phone, T>]
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
        
        init(
            _userId: UUID,
            _identifier: String,
            _birthday: Date,
            _other: String?,
            _addresses: [DTO.UserExtendedInfo<DTO.Address, T>],
            _alternateEmails: [DTO.UserExtendedInfo<DTO.AlternateEmail, T>],
            _phones: [DTO.UserExtendedInfo<DTO.Phone, T>]
        ) {
            self.userId = _userId
            self.identifier = _identifier
            self.birthday = _birthday
            self.other = _other
            self.addresses = _addresses
            self.alternateEmails = _alternateEmails
            self.phones = _phones
        }
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    init(
        userId: UUID,
        identifier: String,
        birthday: Date,
        other: String? = nil,
        addresses: [DTO.UserExtendedInfo<DTO.Address, T>] = [],
        alternateEmails: [DTO.UserExtendedInfo<DTO.AlternateEmail, T>] = [],
        phones: [DTO.UserExtendedInfo<DTO.Phone, T>] = []
    ) {
        self = Self.init(
            _userId: userId,
            _identifier: identifier,
            _birthday: birthday,
            _other: other,
            _addresses: addresses,
            _alternateEmails: alternateEmails,
            _phones: phones
        )
    }
}

extension DTO.UserInfo where T == DTO.Queried {
    static func make(
        from model: User.Info,
        addresses: [User.Info.Extended<User.Info.Address>],
        alternateEmails: [User.Info.Extended<User.Info.AlternateEmail>],
        phones: [User.Info.Extended<User.Info.Phone>],
    ) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internal) {
            var n = try Self.init(
                _userId: model.$user.id,
                _identifier: model.identifier,
                _birthday: model.birthday,
                _other: model.other,
                _addresses: addresses.map { try .make(from: $0).get() },
                _alternateEmails: alternateEmails.map { try .make(from: $0).get() },
                _phones: phones.map { try .make(from: $0).get() }
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updateAt = model.updateAt
            return n
        }
    }
}

extension DTO.UserInfo where T == DTO.Prepare {
    func raw() -> User.Info {
        let info = User.Info()
        info.$user.id = userId
        info.identifier = identifier
        info.birthday = birthday
        info.other = other
        return info
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let userId: UUID
        var id: UUID { userId }
        
        private(set) var updates: [
            PartialKeyPath<DTO.UserInfo<DTO.Prepare>>:
            (QueryBuilder<User.Info>, DTO.UserInfo<DTO.Queried>?) throws -> QueryBuilder<User.Info>
        ] = [:]
        private(set) var needsPeek = false
        
        public init(userId: UUID) {
            self.userId = userId
        }
    }
}

extension DTO.UserInfo.Updater: DTOUpdater {}

public extension DTO.UserInfo.Updater {
    mutating
    func update(identifier: @escaping @autoclosure () throws -> String) {
        updates[\.identifier] = { builder, _ in
            builder.set(\.$identifier, to: try identifier())
        }
    }
    
    mutating
    func update(birthday: @escaping @autoclosure () throws -> Date) {
        updates[\.birthday] = { builder, _ in
            builder.set(\.$birthday, to: try birthday())
        }
    }
    
    mutating
    func update(other: @escaping @autoclosure () throws -> String?) {
        updates[\.other] = { builder, _ in
            builder.set(\.$other, to: try other())
        }
    }
}

public extension DTO.UserInfo.Updater {
    mutating
    func update(identifier: @escaping (DTO.UserInfo<DTO.Queried>) throws -> String) {
        needsPeek = true
        updates[\.identifier] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$identifier, to: try identifier(q))
        }
    }
    
    mutating
    func update(birthday: @escaping (DTO.UserInfo<DTO.Queried>) throws -> Date) {
        needsPeek = true
        updates[\.birthday] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$birthday, to: try birthday(q))
        }
    }
    
    mutating
    func update(other: @escaping (DTO.UserInfo<DTO.Queried>) throws -> String?) {
        needsPeek = true
        updates[\.other] = { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$other, to: try other(q))
        }
    }
}

// MARK: - UserInfoExtended defines

typealias UserModel = User

public extension DTO {
    protocol UserInfoModel: Sendable {
        associatedtype Value: Sendable
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
        @Passive() public internal(set) var updateAt: Date
        
        init(
            _value: T.Value,
            _order: Int16,
            _description: String?
        ) {
            self.value = _value
            self.order = _order
            self.description = _description
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
        )
    }
}

extension DTO.UserExtendedInfo where G == DTO.Queried, T.Value == String {
    static func make(from model: User.Info.Extended<T.Model>) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internal) {
            var n = Self.init(
                _value: model.value,     // 暂时使用强制解包，因为目前用户 Info Value 字段均为 String
                _order: model.order,
                _description: model.description
            )
            n.$id = try model.requireID()
            n.$userInfoId = model.$userInfo.id
            n.$createdAt = model.createdAt
            n.$updateAt = model.updateAt
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
        var id: UUID { userInfoId }
        
        private(set) var updates: [
            PartialKeyPath<DTO.UserExtendedInfo<T, DTO.Prepare>>:
            (QueryBuilder<User.Info.Extended<T.Model>>, DTO.UserExtendedInfo<T, DTO.Queried>?) throws -> QueryBuilder<User.Info.Extended<T.Model>>
        ] = [:]
        private(set)  var needsPeek = false
        
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
