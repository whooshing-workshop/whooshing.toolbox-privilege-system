import PgSQL
import Foundation
import Policy

package extension User {
    final class Info: PGModel, @unchecked Sendable {
        package static let name: String = "user_infos"
        
        package struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userId = PGField("user_id", .uuid)                      .required.unique.foreign(User.self, \.id, onDelete: .cascade)
            let idNumber = PGField("id_number", .string)                .required.unique
            let nickname = PGField("nickname", .string)                 .required
            let birthday = PGField("birthday", .date)                   .required
            let other = PGField("other", .string)
            let createdAt = PGField("created_at", .datetime)            .required
            let updatedAt = PGField("updated_at", .datetime)            .required
            
            package init() {}
        }
        
        package static let fields = Fields()
        
        @ID(key: .id)                                           package var id: UUID?
        
        @Parent(fields.userId)                                  var user: User
        @Field(fields.nickname)                                 var nickname: String
        @Field(fields.idNumber)                                 var identifier: String
        @Field(fields.birthday)                                 var birthday: Date
        @Field(fields.other)                                    var other: String?
        
        @Children(for: \Extended<Address>.$userInfo)            var addresses: [Extended<Address>]
        @Children(for: \Extended<AlternateEmail>.$userInfo)     var alternateEmails: [Extended<AlternateEmail>]
        @Children(for: \Extended<Phone>.$userInfo)              var phones: [Extended<Phone>]
        
        @Timestamp(fields.createdAt, on: .create)               var createdAt: Date!
        @Timestamp(fields.updatedAt, on: .update)               var updatedAt: Date!
        
        package init() {}
        
        package typealias MIG = DefaultMIG<Info>
    }
}
