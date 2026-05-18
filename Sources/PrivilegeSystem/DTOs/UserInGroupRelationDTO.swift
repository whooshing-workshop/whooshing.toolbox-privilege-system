import Fluent
import Foundation
import ErrorHandle
import PrivilegeModule
import LoggingAdvanced
import AnyCodable

public typealias PUserInGroupRelation = DTO.UserInGroupRelation<DTO.Prepare>
public typealias QUserInGroupRelation = DTO.UserInGroupRelation<DTO.Queried>

public extension DTO {
    struct UserInGroupRelation<T: Status>: DTOModel, Sendable, Hashable {
        public let user: User<Queried>
        public let group: Group<Queried>
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        
        package typealias AssociatedModel = UserGroupPivot
        private let m: AssociatedModel?
        
        init(
            _user: User<Queried>,
            _group: Group<Queried>,
            _model: AssociatedModel?
        ) {
            self.user = _user
            self.group = _group
            self.m = _model
        }
    }
}

public extension DTO.UserInGroupRelation where T == DTO.Prepare {
    init(
        user: DTO.User<DTO.Queried>,
        group: DTO.Group<DTO.Queried>
    ) {
        self = Self.init(_user: user, _group: group, _model: nil)
    }
}

extension DTO.UserInGroupRelation where T == DTO.Queried {
    var model: UserGroupPivot {
        guard let m = m else {
            fatalError("查询后的 DTO 模型应当有数据库表实例，这里未找到")
        }
        return m
    }
    
    static func make(from model: UserGroupPivot) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInGroupDTOFailed, category: .internal) {
            var n = Self.init(
                _user: try .make(from: model.user).get(),
                _group: try .make(from: model.group).get(),
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            return n
        }
    }
}

infix operator =| : MappingPrecedence

public func =| (
    left: DTO.User<DTO.Queried>,
    right: DTO.Group<DTO.Queried>
) -> DTO.UserInGroupRelation<DTO.Prepare> {
    .init(user: left, group: right)
}

extension DTO.UserInGroupRelation: CustomStringConvertible, Loggerable {
    public var description: String {
        let isQueried = T.self == DTO.Queried.self
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        
        let data: [String: AnyCodable] = [
            "id": AnyCodable(isQueried ? "\(self.id)" : nil),
            "user_id": AnyCodable("\(self.user.id)"),
            "group_id": AnyCodable("\(self.group.id)"),
            "created_at": AnyCodable(isQueried ? "\(self.createdAt)" : nil)
        ]

        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
}

extension DTO.UserInGroupRelation where T == DTO.Prepare {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(user)
        hasher.combine(group)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.user == rhs.user &&
        lhs.group == rhs.group
    }
}

extension DTO.UserInGroupRelation where T == DTO.Queried {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(user)
        hasher.combine(group)
        hasher.combine(id)
        hasher.combine(createdAt)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.user == rhs.user &&
        lhs.group == rhs.group &&
        lhs.id == rhs.id &&
        lhs.createdAt == rhs.createdAt
    }
}

public extension DTO.UserInGroupRelation where T == DTO.Prepare {
    func like(_ rhs: QUserInGroupRelation) -> Bool {
        self.user == rhs.user &&
        self.group == rhs.group
    }
}

public extension DTO.UserInGroupRelation where T == DTO.Queried {
    func like(_ rhs: PUserInGroupRelation) -> Bool {
        self.user == rhs.user &&
        self.group == rhs.group
    }
}

public extension Collection where Element == PUserInGroupRelation {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QUserInGroupRelation {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QUserInGroupRelation {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PUserInGroupRelation {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
