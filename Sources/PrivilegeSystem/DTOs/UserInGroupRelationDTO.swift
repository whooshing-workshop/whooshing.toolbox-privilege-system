import Fluent
import Foundation
import ErrorHandle
import PrivilegeModule

public extension DTO {
    struct UserInGroupRelation<T: Status>: Sendable {
        public let user: User<Queried>
        public let group: Group<Queried>
        
        @Passive public internal(set) var id: UUID
        @Passive public internal(set) var createdAt: Date
        
        typealias AssociatedModel = UserGroupPivot
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
                _user: try .make(from: model.primaryModel).get(),
                _group: try .make(from: model.secondaryModel).get(),
                _model: model
            )
            n.$id = try model.requireID()
            n.$createdAt = model.createdAt
            return n
        }
    }
}

infix operator ~> : MappingPrecedence

public func ~> (
    left: DTO.User<DTO.Queried>,
    right: DTO.Group<DTO.Queried>
) -> DTO.UserInGroupRelation<DTO.Prepare> {
    .init(user: left, group: right)
}
