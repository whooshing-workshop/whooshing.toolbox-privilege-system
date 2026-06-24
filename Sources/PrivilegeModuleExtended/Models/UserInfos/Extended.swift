import Foundation
import DTOBuilder

public extension __SDBM.User.Info {
    final class Extended<T: __SDBM.User.Info.Model>: PGModel, @unchecked Sendable {
        public static var name: String { "user_info_" + T.tableExtendedName }
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userInfoId = PGField("user_info_id", .uuid)             .required.unique(composite: name + ".unique").foreign(__SDBM.User.Info.self, \.id, onDelete: .cascade)
            let value = PGField(T.valueFieldName, T.pgFieldType)        .required.unique(composite: name + ".unique")
            let order = PGField("order", .int16)                        .required.unique(composite: name + ".unique")
            let summary = PGField("summary", .string)
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public let fields = Fields()
        
        @ID(key: .id)                                   public var id: UUID?
        
        @Parent(fields.userInfoId)                      package var userInfo: __SDBM.User.Info
        @Field(fields.value)                            package var value: T.Value
        @Field(fields.order)                            package var order: Int16
        @Field(fields.summary)                          package var summary: String?
        
        @Timestamp(fields.createdAt, on: .create)       package var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       package var updatedAt: Date!
        
        public init() {}
        
        public typealias MIG = DefaultMIG<Extended<T>>
    }
}

public extension __SDBM.User.Info {
    typealias Model = UserInfoExtends.Model
    typealias Address = UserInfoExtends.Address
    typealias AlternateEmail = UserInfoExtends.AlternateEmail
    typealias Phone = UserInfoExtends.Phone
}

public enum UserInfoExtends {
    public protocol Model {
        associatedtype Value: Sendable & Codable & Hashable
        static var tableExtendedName: String { get }
        static var valueFieldName: String { get }
        static var pgFieldType: DatabaseSchema.DataType { get }
    }
    
    public struct Address: Model {
        public typealias Value = String
        public static let tableExtendedName = "addresses"
        public static let valueFieldName = "address"
        public static let pgFieldType: DatabaseSchema.DataType = .string
    }
    
    public struct AlternateEmail: Model {
        public typealias Value = String
        public static let tableExtendedName = "alternate_emails"
        public static let valueFieldName = "alternate_email"
        public static let pgFieldType: DatabaseSchema.DataType = .string
    }
    
    public struct Phone: Model {
        public typealias Value = String
        public static let tableExtendedName = "phones"
        public static let valueFieldName = "phone"
        public static let pgFieldType: DatabaseSchema.DataType = .string
    }
}
