import PgSQL
import Fluent
import Foundation

protocol ACLType {
    static var namePrefix: String { get }
}

final class ACLExp<T: ACLType>: PGModel, @unchecked Sendable {
    
    static var name: String { T.namePrefix + "_acl_exps" }
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                           .primary
        let parentId = PGField("parent_id", .uuid)              .foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        let ruleId = PGField("rule_id", .uuid)                  .required.foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        let position = PGField("position", .string)
        let type = PGField("type", .string)                     .required
        let op = PGField("operator", .string)
        let value = PGField("value", .string)
        
        init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @OptionalParent(fields.parentId)                var parent: ACLExp<T>?
    @Parent(fields.ruleId)                          var rule: ACLExp<T>
    @Field(fields.position)                         var position: String
    @Field(fields.type)                             var type: String
    @Field(fields.op)                               var op: String?
    @Field(fields.value)                            var value: String?
    
    init() {}
    
    typealias MIG = DefaultMIG<ACLExp<T>>
}
