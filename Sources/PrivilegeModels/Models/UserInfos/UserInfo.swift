import Foundation
import DTOBuilder

public extension __SDBM.User {
    final class Info: PGModel, @unchecked Sendable {
        public static let name: String = "user_infos"
        
        public struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userId = PGField("user_id", .uuid)                      .required.unique.foreign(__SDBM.User.self, \.id, onDelete: .cascade)
            let idNumber = PGField("id_number", .string)                .required.unique
            let nickname = PGField("nickname", .string)                 .required
            let birthday = PGField("birthday", .date)                   .required
            let other = PGField("other", .string)
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            public init() {}
        }
        
        public static let fields = Fields()
        
        @ID(key: .id)                                           public var id: UUID?
        
        @Parent(fields.userId)                                  package var user: __SDBM.User
        @Field(fields.nickname)                                 package var nickname: String
        @Field(fields.idNumber)                                 package var identifier: String
        @Field(fields.birthday)                                 package var birthday: Date
        @Field(fields.other)                                    package var other: String?
        
        @Children(for: \Extended<Address>.$userInfo)            package var addresses: [Extended<Address>]
        @Children(for: \Extended<AlternateEmail>.$userInfo)     package var alternateEmails: [Extended<AlternateEmail>]
        @Children(for: \Extended<Phone>.$userInfo)              package var phones: [Extended<Phone>]
        
        @Timestamp(fields.createdAt, on: .create)               package var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)               package var updatedAt: Date!
        
        public init() {}
        
        public typealias MIG = DefaultMIG<Info>
    }
}
