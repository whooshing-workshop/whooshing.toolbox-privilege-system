import PgSQL
import Fluent
import Foundation

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
    }
}

extension User.Info.Extended {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = User.Info.Extended<T>
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
