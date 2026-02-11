import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import Collections
import PrivilegeModule

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
        @Passive() public internal(set) var updatedAt: Date
        
        typealias AssociatedModel = UserModel.Info
        private let m: AssociatedModel?
        
        init(
            _userId: UUID,
            _identifier: String,
            _birthday: Date,
            _other: String?,
            _addresses: [DTO.UserExtendedInfo<DTO.Address, T>],
            _alternateEmails: [DTO.UserExtendedInfo<DTO.AlternateEmail, T>],
            _phones: [DTO.UserExtendedInfo<DTO.Phone, T>],
            _model: AssociatedModel?
        ) {
            self.userId = _userId
            self.identifier = _identifier
            self.birthday = _birthday
            self.other = _other
            self.addresses = _addresses
            self.alternateEmails = _alternateEmails
            self.phones = _phones
            self.m = _model
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
            _phones: phones,
            _model: nil
        )
    }
}

extension DTO.UserInfo where T == DTO.Queried {
    var model: User.Info {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
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
                _phones: phones.map { try .make(from: $0).get() },
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
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
        package var id: UUID { userId }
        
        package private(set) var updates: OrderedDictionary<
            PartialKeyPath<DTO.UserInfo<DTO.Prepare>>,
            (QueryBuilder<User.Info>, DTO.UserInfo<DTO.Queried>?) throws -> QueryBuilder<User.Info>
        > = [:]
        package private(set) var needsPeek = false
        
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

extension DTO.UserInfo: Encodable where T == DTO.Queried {}
