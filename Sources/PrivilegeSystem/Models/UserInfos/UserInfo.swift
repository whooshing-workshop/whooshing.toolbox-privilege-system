import PgSQL
import Fluent
import Foundation
import Vapor
import DataConvertable
import Cryptos
import ErrorHandle

extension User {
    final class Info: PGModel, @unchecked Sendable {
        static let name: String = "user_infos"
        
        struct Fields: PGFields {
            let id = PGField("id", .uuid)                               .primary
            let userId = PGField("user_id", .uuid)                      .required.unique.foreign(User.self, \.id, onDelete: .cascade)
            let idNumber = PGField("id_number", .string)                .required.unique
            let birthday = PGField("birthday", .date)                   .required
            let other = PGField("other", .string)
            let createdAt = PGField("create_at", .string)               .required
            let updateAt = PGField("update_at", .string)                .required
        }
        
        static let fields = Fields()
        
        @ID(key: .id)                                           var id: UUID?
        
        @Parent(fields.userId)                                  var user: User
        @Field(fields.idNumber)                                 var identifier: String
        @Field(fields.birthday)                                 var birthday: Date
        @Field(fields.other)                                    var other: String?
        
        @Children(for: \Extended<Address>.$userInfo)            var addresses: [Extended<Address>]
        @Children(for: \Extended<AlternateEmail>.$userInfo)     var alternateEmails: [Extended<AlternateEmail>]
        @Children(for: \Extended<Phone>.$userInfo)              var phones: [Extended<Phone>]
        
        @Timestamp(fields.createdAt, on: .create)               var createdAt: Date!
        @Timestamp(fields.updateAt, on: .update)                var updateAt: Date!
        
        init() {}
        
        typealias MIG = DefaultMIG<Info>
    }
}
