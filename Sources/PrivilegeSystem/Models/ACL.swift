import PgSQL
import Fluent
import Foundation

final class ACL: PGModel, @unchecked Sendable {
    
    static let name = "acl_exps"
    
    struct Fields: PGFields {
        
        let id = PGField("id", .uuid)                           .primary
        let parentId = PGField("parent_id", .uuid)              .foreign(ACL.self, .id, onDelete: .cascade)
        let ruleId = PGField("rule_id", .uuid)                  .required.foreign(ACL.self, .id, onDelete: .cascade)
        let position = PGField("position", .string)
        let type = PGField("type", .string)                     .required
        let op = PGField("operator", .string)
        let value = PGField("value", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @OptionalParent(fields.parentId)                var parent: ACL?
    @Parent(fields.ruleId)                          var rule: ACL
    @Field(fields.position)                         var position: String
    @Field(fields.type)                             var type: String
    @Field(fields.op)                               var op: String?
    @Field(fields.value)                            var value: String?
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension ACL {
    @usableFromInline
    struct MIG: TdeMIG, Sendable {
        @usableFromInline
        typealias DataModel = ACL
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}
