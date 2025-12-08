import PgSQL
import Fluent
import Foundation
import ACL

extension User.Info {
    final class Extended<T: User.Info.Model>: PGModel, @unchecked Sendable {
        static var name: String { "user_info_" + T.tableExtendedName }
        
        struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userInfoId = PGField("user_info_id", .uuid)             .required.unique.foreign(User.Info.self, \.id, onDelete: .cascade)
            let value = PGField(T.valueFieldName, .string)              .required
            let order = PGField("order", .int16)                        .required
            let description = PGField("description", .string)
            let createdAt = PGField("create_at", .string)               .required
            let updateAt = PGField("update_at", .string)                .required
        }
        
        let fields = Fields()
        
        @ID(key: .id)                                   var id: UUID?
        
        @Parent(fields.userInfoId)                      var userInfo: User.Info
        @Field(fields.value)                            var value: String
        @Field(fields.order)                            var order: Int16
        @Field(fields.description)                      var description: String?
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updateAt, on: .update)        var updateAt: Date!
        
        init() {}
        
        typealias MIG = DefaultMIG<Extended<T>>
    }
}

extension User.Info {
    typealias Model = UserInfoExtends.Model
    typealias Address = UserInfoExtends.Address
    typealias AlternateEmail = UserInfoExtends.AlternateEmail
    typealias Phone = UserInfoExtends.Phone
}

public enum UserInfoExtends {
    public protocol Model {
        static var tableExtendedName: String { get }
        static var valueFieldName: String { get }
    }
    
    public struct Address: Model {
        public static let tableExtendedName = "addresses"
        public static let valueFieldName = "address"
    }
    
    public struct AlternateEmail: Model {
        public static let tableExtendedName = "alternate_emails"
        public static let valueFieldName = "alternate_email"
    }
    
    public struct Phone: Model {
        public static let tableExtendedName = "phones"
        public static let valueFieldName = "phone"
    }
}
