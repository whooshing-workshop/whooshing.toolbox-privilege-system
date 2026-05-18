import Vapor
import Fluent
import DataConvertable
import ErrorHandle
import Cryptos
import Policy
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable

public typealias EIAddress = DTO.Address
public typealias EIAlternateEmail = DTO.AlternateEmail
public typealias EIPhone = DTO.Phone

public typealias PAddressSlice = DTO.InfoSlice<DTO.Address, DTO.Prepare>
public typealias QAddressSlice = DTO.InfoSlice<DTO.Address, DTO.Queried>

public typealias PAlternateEmailSlice = DTO.InfoSlice<DTO.AlternateEmail, DTO.Prepare>
public typealias QAlternateEmailSlice = DTO.InfoSlice<DTO.AlternateEmail, DTO.Queried>

public typealias PPhoneSlice = DTO.InfoSlice<DTO.Phone, DTO.Prepare>
public typealias QPhoneSlice = DTO.InfoSlice<DTO.Phone, DTO.Queried>

public typealias PExtendedSlice<T: DTO.UserInfoModel> = DTO.InfoSlice<T, DTO.Prepare>
public typealias QExtendedSlice<T: DTO.UserInfoModel> = DTO.InfoSlice<T, DTO.Queried>

public extension DTO {
    protocol UserInfoModel: Sendable {
        associatedtype Value: Sendable & Codable & Hashable
        associatedtype Model: UserInfoExtends.Model
        static var description: String { get }
    }
    
    struct InfoSlice<G: UserInfoModel, T: Status>: DTOModel, Sendable {
        public let value: G.Value
        public let order: Int16
        public let description: String?
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var userInfoId: UUID
        @Passive public internal(set) var createdAt: Date
        @Passive public internal(set) var updatedAt: Date
        
        package typealias AssociatedModel = UserModel.Info.Extended<G.Model>
        private let m: AssociatedModel?
        
        init(
            _value: G.Value,
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

public extension DTO.InfoSlice where T == DTO.Prepare {
    init(value: G.Value, order: Int16, description: String? = nil) {
        self = Self.init(
            _value: value,
            _order: order,
            _description: description,
            _model: nil
        )
    }
}

extension DTO.InfoSlice where T == DTO.Queried, G.Value == String {
    var model: User.Info.Extended<G.Model> {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    public static func make(from model: User.Info.Extended<G.Model>) -> Res<Self, PrivilegeSystem.Errcase> {
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

extension DTO.InfoSlice where T == DTO.Prepare, G.Value == String {
    func raw(for userInfoId: UUID) -> User.Info.Extended<G.Model> {
        let info = User.Info.Extended<G.Model>()
        info.$userInfo.id = userInfoId
        info.value = value
        info.order = order
        info.description = description
        return info
    }
}

public extension DTO.InfoSlice where G.Value == String, T == DTO.Prepare {
    struct Updater: @unchecked Sendable {
        public let infoSliceId: UUID
        package var id: UUID { infoSliceId }
        
        package let updates: OrderedDictionary<
            PartialKeyPath<DTO.InfoSlice<G, DTO.Prepare>>,
            (QueryBuilder<User.Info.Extended<G.Model>>, DTO.InfoSlice<G, DTO.Queried>?) throws -> QueryBuilder<User.Info.Extended<G.Model>>
        >
        package let needsPeek: Bool
        
        public init(infoSliceId: UUID) {
            self.infoSliceId = infoSliceId
            self.updates = [:]
            self.needsPeek = false
        }
        
        package init(
            id: UUID,
            updates: OrderedDictionary<
                PartialKeyPath<DTO.InfoSlice<G, DTO.Prepare>>,
                (QueryBuilder<User.Info.Extended<G.Model>>, DTO.InfoSlice<G, DTO.Queried>?) throws -> QueryBuilder<User.Info.Extended<G.Model>>
            >,
            needsPeek: Bool
        ) {
            self.infoSliceId = id
            self.updates = updates
            self.needsPeek = needsPeek
        }
    }
}

extension DTO.InfoSlice.Updater: DTOUpdater {}

public extension DTO.InfoSlice.Updater {
    func update(value: @escaping @autoclosure () throws -> G.Value) -> Self {
        generate(key: \.value) { builder, _ in
            builder.set(\.$value, to: try value())
        }
    }
    
    func update(order: @escaping @autoclosure () throws -> Int16) -> Self {
        generate(key: \.order) { builder, _ in
            builder.set(\.$order, to: try order())
        }
    }
    
    func update(description: @escaping @autoclosure () throws -> String?) -> Self {
        generate(key: \.description) { builder, _ in
            builder.set(\.$description, to: try description())
        }
    }
}

public extension DTO.InfoSlice.Updater {
    func update(value: @escaping (DTO.InfoSlice<G, DTO.Queried>) throws -> G.Value) -> Self {
        generate(needsPeek: true, key: \.value) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$value, to: try value(q))
        }
    }
    
    func update(order: @escaping (DTO.InfoSlice<G, DTO.Queried>) throws -> Int16) -> Self {
        generate(needsPeek: true, key: \.order) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$order, to: try order(q))
        }
    }
    
    func update(description: @escaping (DTO.InfoSlice<G, DTO.Queried>) throws -> String?) -> Self {
        generate(needsPeek: true, key: \.description) { builder, query in
            guard let q = query else { fatalError("应当提供 Query 结果，却没有提供") }
            return builder.set(\.$description, to: try description(q))
        }
    }
}

extension DTO.InfoSlice: Encodable where T == DTO.Queried {
    enum CodingKeys: String, CodingKey {
        case value
        case order
        case description
        case id
        case userInfoId = "user_info_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(value, forKey: .value)
        try container.encode(order, forKey: .order)
        try container.encode(description, forKey: .description)
        try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
        try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
    }
}

extension DTO.InfoSlice: Query.Queriable where T == DTO.Queried, G.Value == String {
    public typealias Model = User.Info.Extended<G.Model>
    public typealias ErrorType = PrivilegeSystem.Errcase
    public static var paths: [PartialKeyPath<Self>: PartialKeyPath<Model>] {[
        \.value: \.$value,
        \.order: \.$order,
        \.description: \.$description,
        \.id: \.$id,
        \.userInfoId: \.$userInfo.$id,
        \.createdAt: \.$createdAt,
        \.updatedAt: \.$updatedAt
    ]}
    
    public static func buildAllFields<Base>(_ builder: QueryBuilder<Base>) -> QueryBuilder<Base> where Base: FluentKit.Model {
        builder
            .field(Model.self, \.$value)
            .field(Model.self, \.$order)
            .field(Model.self, \.$description)
            .field(Model.self, \.$id)
            .field(Model.self, \.$userInfo.$id)
            .field(Model.self, \.$createdAt)
            .field(Model.self, \.$updatedAt)
    }
}

extension DTO.InfoSlice: Loggerable {
    public var logDescription: String {
        let isQueried = G.self == DTO.Queried.self
        let statusLabel = "\(G.self)".components(separatedBy: ".").last ?? "\(G.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "user_info_id": AnyCodable(isQueried ? "\(self.userInfoId)" : nil),
            "value": AnyCodable("[PROTECTED]"),
            "order": AnyCodable(self.order),
            "description": AnyCodable(self.description),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil),
            "updated_at": AnyCodable(isQueried ? "\(self.updatedAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
}

extension DTO.InfoSlice where T == DTO.Prepare {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
        hasher.combine(order)
        hasher.combine(description)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.value == rhs.value &&
        lhs.order == rhs.order &&
        lhs.description == rhs.description
    }
}

extension DTO.InfoSlice: Hashable {
    public func hash(into hasher: inout Hasher) {
        if T.self == DTO.Prepare.self {
            hasher.combine(value)
            hasher.combine(order)
            hasher.combine(description)
        } else {
            hasher.combine(value)
            hasher.combine(order)
            hasher.combine(description)
            hasher.combine(id)
            hasher.combine(userInfoId)
            hasher.combine(createdAt)
            hasher.combine(updatedAt)
        }
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        if T.self == DTO.Prepare.self {
            lhs.value == rhs.value &&
            lhs.order == rhs.order &&
            lhs.description == rhs.description
        } else {
            lhs.value == rhs.value &&
            lhs.order == rhs.order &&
            lhs.description == rhs.description &&
            lhs.id == rhs.id &&
            lhs.userInfoId == rhs.userInfoId &&
            lhs.createdAt == rhs.createdAt &&
            lhs.updatedAt == rhs.updatedAt
        }
    }
}

public extension DTO.InfoSlice where T == DTO.Prepare {
    func like(_ rhs: QExtendedSlice<G>) -> Bool {
        self.value == rhs.value &&
        self.order == rhs.order &&
        self.description == rhs.description
    }
}

public extension DTO.InfoSlice where T == DTO.Queried {
    func like(_ rhs: PExtendedSlice<G>) -> Bool {
        self.value == rhs.value &&
        self.order == rhs.order &&
        self.description == rhs.description
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == QExtendedSlice<T>, Element == PExtendedSlice<T> {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection {
    func like<C, T>(_ rhs: C) -> Bool where C: Collection, C.Element == PExtendedSlice<T>, Element == QExtendedSlice<T> {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
