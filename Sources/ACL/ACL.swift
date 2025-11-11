import PgSQL
import Fluent
import Foundation

public protocol ACLType {
    static var namePrefix: String { get }
}

public final class ACLExp<T: ACLType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.namePrefix + "_acl_exps" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let parentId = PGField("parent_id", .uuid)               .foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        public let ruleId = PGField("rule_id", .uuid)                   .required.foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        public let position = PGField("position", .string)
        public let type = PGField("type", .string)                      .required
        public let op = PGField("operator", .string)
        public let value = PGField("value", .string)
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @OptionalParent(fields.parentId)                public var parent: ACLExp<T>?
    @Parent(fields.ruleId)                          public var rule: ACLExp<T>
    @Field(fields.position)                         public var position: String
    @Field(fields.type)                             public var type: String
    @Field(fields.op)                               public var op: String?
    @Field(fields.value)                            public var value: String?
    
    public init() {}
    
    public typealias MIG = DefaultMIG<ACLExp<T>>
}
