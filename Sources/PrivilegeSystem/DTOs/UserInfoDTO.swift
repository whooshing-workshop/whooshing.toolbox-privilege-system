import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Policy
import Cryptos
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable

public typealias PUserInfo = DTO.UserInfo<DTO.Prepare>
public typealias QUserInfo = DTO.UserInfo<DTO.Queried>

public extension DTO {
    struct UserInfo<T: Status>: DTOModel, Sendable, Hashable {
        public let nickname: String
        public let identifier: String
        public let birthday: Date
        public let other: String?
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var userId: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
        package typealias AssociatedModel = UserModel.Info
        private let m: AssociatedModel?
        
        init(
            _nickname: String,
            _identifier: String,
            _birthday: Date,
            _other: String?,
            _model: AssociatedModel?
        ) {
            self.nickname = _nickname
            self.identifier = _identifier
            self.birthday = _birthday
            self.other = _other
            self.m = _model
        }
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    init(
        nickname: String,
        identifier: String,
        birthday: Date,
        other: String? = nil,
    ) {
        self = Self.init(
            _nickname: nickname,
            _identifier: identifier,
            _birthday: birthday,
            _other: other,
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
    
    public static func make(
        from model: User.Info
    ) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internal) {
            var n = Self.init(
                _nickname: model.nickname,
                _identifier: model.identifier,
                _birthday: model.birthday,
                _other: model.other,
                _model: model
            )
            n.$userId = model.$user.id
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            n.$updatedAt = model.updatedAt
            return n
        }
    }
}

extension DTO.UserInfo where T == DTO.Prepare {
    func raw(for userId: UUID) -> User.Info {
        let info = User.Info()
        info.$user.id = userId
        info.nickname = nickname
        info.identifier = identifier
        info.birthday = birthday
        info.other = other
        return info
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let userInfoId: UUID
        package var id: UUID { userInfoId }
        
        package let updates: OrderedDictionary<
            PartialKeyPath<DTO.UserInfo<DTO.Prepare>>,
            (QueryBuilder<User.Info>, DTO.UserInfo<DTO.Queried>?) throws -> QueryBuilder<User.Info>
        >
        package let needsPeek: Bool
        
        public init(userInfoId: UUID) {
            self.userInfoId = userInfoId
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<DTO.UserInfo<DTO.Prepare>>,
                (QueryBuilder<User.Info>, DTO.UserInfo<DTO.Queried>?) throws -> QueryBuilder<User.Info>
            >,
            needsPeek: Bool
        ) {
            self.userInfoId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension DTO.UserInfo.Updater: DTOUpdater {}

public extension DTO.UserInfo.Updater {
    func update(identifier: @escaping @autoclosure () throws -> String) -> Self {
        generate(key: \.identifier) { builder, _ in
            builder.set(\.$identifier, to: try identifier())
        }
    }
    
    func update(nickname: @escaping @autoclosure () throws -> String) -> Self {
        generate(key: \.nickname) { builder, _ in
            builder.set(\.$nickname, to: try nickname())
        }
    }
    
    func update(birthday: @escaping @autoclosure () throws -> Date) -> Self {
        generate(key: \.birthday) { builder, _ in
            builder.set(\.$birthday, to: try birthday())
        }
    }
    
    func update(other: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.other) { builder, _ in
            builder.set(\.$other, to: try other())
        }
    }
}

public extension DTO.UserInfo.Updater {
    func update(identifier: @escaping (DTO.UserInfo<DTO.Queried>) throws -> String) -> Self {
        generate(needsPeek: true, key: \.identifier) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$identifier, to: try identifier(q))
        }
    }
    
    func update(nickname: @escaping (DTO.UserInfo<DTO.Queried>) throws -> String) -> Self {
        generate(needsPeek: true, key: \.nickname) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$nickname, to: try nickname(q))
        }
    }
    
    func update(birthday: @escaping (DTO.UserInfo<DTO.Queried>) throws -> Date) -> Self {
        generate(needsPeek: true, key: \.birthday) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$birthday, to: try birthday(q))
        }
    }
    
    func update(other: @escaping (DTO.UserInfo<DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.other) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$other, to: try other(q))
        }
    }
}

extension DTO.UserInfo: Encodable where T == DTO.Queried {
    enum CodingKeys: String, CodingKey {
        case userId
        case nickname
        case identifier
        case birthday
        case other
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(other, forKey: .other)
        try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
        try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
    }
}

extension DTO.UserInfo: Query.Queriable where T == DTO.Queried {
    public typealias Model = User.Info
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.nickname: \.$nickname,
        \.identifier: \.$identifier,
        \.birthday: \.$birthday,
        \.other: \.$other,
        \.id: \.$id,
        \.userId: \.$user.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$nickname)
            .field(Model.self, \.$identifier)
            .field(Model.self, \.$birthday)
            .field(Model.self, \.$other)
            .field(Model.self, \.$id)
            .field(Model.self, \.$user.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

extension DTO.UserInfo: CustomStringConvertible, Loggerable {
    public var description: String {
        let isQueried = T.self == DTO.Queried.self
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "user_id": AnyCodable(isQueried ? "\(self.userId)" : nil),
            "nickname": AnyCodable(self.nickname),
            "identifier": AnyCodable(self.identifier),
            "birthday": AnyCodable("\(self.birthday)"),
            "other": AnyCodable(self.other),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil),
            "updated_at": AnyCodable(isQueried ? "\(self.updatedAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
}

extension DTO.UserInfo where T == DTO.Prepare {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(nickname)
        hasher.combine(identifier)
        hasher.combine(birthday)
        hasher.combine(other)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nickname == rhs.nickname &&
        lhs.identifier == rhs.identifier &&
        lhs.birthday == rhs.birthday &&
        lhs.other == rhs.other
    }
}

extension DTO.UserInfo where T == DTO.Queried {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(nickname)
        hasher.combine(identifier)
        hasher.combine(birthday)
        hasher.combine(other)
        hasher.combine(id)
        hasher.combine(userId)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.nickname == rhs.nickname &&
        lhs.identifier == rhs.identifier &&
        lhs.birthday == rhs.birthday &&
        lhs.other == rhs.other &&
        lhs.id == rhs.id &&
        lhs.userId == rhs.userId &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    func like(_ rhs: QUserInfo) -> Bool {
        self.nickname == rhs.nickname &&
        self.identifier == rhs.identifier &&
        self.birthday == rhs.birthday &&
        self.other == rhs.other
    }
}

public extension DTO.UserInfo where T == DTO.Queried {
    func like(_ rhs: PUserInfo) -> Bool {
        self.nickname == rhs.nickname &&
        self.identifier == rhs.identifier &&
        self.birthday == rhs.birthday &&
        self.other == rhs.other
    }
}

public extension Collection where Element == PUserInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QUserInfo {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QUserInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PUserInfo {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
