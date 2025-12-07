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
    }
}

public extension DTO.UserInfo where T == DTO.Prepare {
    init(
        userId: UUID,
        identifier: String,
        birthday: Date,
        other: String?,
        addresses: [DTO.UserExtendedInfo<DTO.Address, T>],
        alternateEmails: [DTO.UserExtendedInfo<DTO.AlternateEmail, T>],
        phones: [DTO.UserExtendedInfo<DTO.Phone, T>]
    ) {
        self.userId = userId
        self.identifier = identifier
        self.birthday = birthday
        self.other = other
        self.addresses = addresses
        self.alternateEmails = alternateEmails
        self.phones = phones
    }
}

extension DTO.UserInfo where T == DTO.Queried {
    static func make(
        from model: User.Info,
        addresses: [User.Info.Extended<User.Info.Address>],
        alternateEmails: [User.Info.Extended<User.Info.AlternateEmail>],
        phones: [User.Info.Extended<User.Info.Phone>],
    ) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internel) {
            var n = Self.init(
                userId: model.$user.id,
                identifier: model.identifier,
                birthday: model.birthday,
                other: model.other,
                addresses: addresses.map { .init(value: $0.value, order: $0.order, description: $0.description) },
                alternateEmails: alternateEmails.map { .init(value: $0.value, order: $0.order, description: $0.description) },
                phones: phones.map { .init(value: $0.value, order: $0.order, description: $0.description) }
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

// MARK: - UserInfoExtended defines

typealias UserModel = User

public extension DTO {
    protocol UserInfoModel: Sendable {
        associatedtype Value: Sendable
    }
    
    struct UserExtendedInfo<T: UserInfoModel, G: Status>: Sendable {
        public let value: T.Value
        public let order: Int16
        public let description: String?
        
        @Passive() public internal(set) var id: UUID
        @Passive() public internal(set) var userInfoId: UUID
        @Passive() public internal(set) var createdAt: Date
        @Passive() public internal(set) var updateAt: Date
    }
    
    struct Address: UserInfoModel {
        public typealias Value = String
        typealias Model = UserModel.Info.Address
    }
    
    struct AlternateEmail: UserInfoModel {
        public typealias Value = String
        typealias Model = UserModel.Info.AlternateEmail
    }
    
    struct Phone: UserInfoModel {
        public typealias Value = String
        typealias Model = UserModel.Info.Phone
    }
}

protocol __UserInfoModel: Sendable {
    associatedtype Model: UserModel.Info.Model
}

extension DTO.Address: __UserInfoModel {}
extension DTO.AlternateEmail: __UserInfoModel {}
extension DTO.Phone: __UserInfoModel {}

public extension DTO.UserExtendedInfo where G == DTO.Prepare {
    init(value: T.Value, order: Int16, description: String?) {
        self.value = value
        self.order = order
        self.description = description
    }
}

extension DTO.UserExtendedInfo where G == DTO.Queried, T: __UserInfoModel, T.Value == String {
    static func make(from model: User.Info.Extended<T.Model>) -> Res<Self, PrivilegeSystem.Errcase> {
        .init(throws: .userInfoDTOFailed, category: .internel) {
            var n = Self.init(
                value: model.value,     // 暂时使用强制解包，因为目前用户 Info Value 字段均为 String
                order: model.order,
                description: model.description
            )
            n.$id = try model.requireID()
            n.$userInfoId = model.$userInfo.id
            n.$createdAt = model.createdAt
            n.$updateAt = model.updateAt
            return n
        }
    }
}

extension DTO.UserExtendedInfo where G == DTO.Prepare, T: __UserInfoModel, T.Value == String {
    func raw(for userInfoId: UUID) -> User.Info.Extended<T.Model> {
        let info = User.Info.Extended<T.Model>()
        info.$userInfo.id = userInfoId
        info.value = value
        info.order = order
        info.description = description
        return info
    }
}
