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
    }
}

extension User.Info {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = User.Info
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}

extension User.Info {
    protocol Model {
        static var tableExtendedName: String { get }
        static var valueFieldName: String { get }
    }
    
    struct Address: Model {
        static let tableExtendedName = "addresses"
        static let valueFieldName = "address"
    }
    
    struct AlternateEmail: Model {
        static let tableExtendedName = "alternate_emails"
        static let valueFieldName = "alternate_email"
    }
    
    struct Phone: Model {
        static let tableExtendedName = "phones"
        static let valueFieldName = "phone"
    }
}
