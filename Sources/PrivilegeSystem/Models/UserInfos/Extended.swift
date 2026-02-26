import PgSQL
import Fluent
import Foundation
import Policy

package extension User.Info {
    final class Extended<T: User.Info.Model>: PGModel, @unchecked Sendable {
        package static var name: String { "user_info_" + T.tableExtendedName }
        
        package struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userInfoId = PGField("user_info_id", .uuid)             .required.unique.foreign(User.Info.self, \.id, onDelete: .cascade)
            let value = PGField(T.valueFieldName, .string)              .required
            let order = PGField("order", .int16)                        .required
            let description = PGField("description", .string)
            let createdAt = PGField("created_at", .datetime)               .required
            let updatedAt = PGField("updated_at", .datetime)               .required
            
            package init() {}
        }
        
        package let fields = Fields()
        
        @ID(key: .id)                                   package var id: UUID?
        
        @Parent(fields.userInfoId)                      var userInfo: User.Info
        @Field(fields.value)                            var value: String
        @Field(fields.order)                            var order: Int16
        @Field(fields.description)                      var description: String?
        
        @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)       var updatedAt: Date!
        
        package init() {}
        
        package typealias MIG = DefaultMIG<Extended<T>>
    }
}

package extension User.Info {
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
