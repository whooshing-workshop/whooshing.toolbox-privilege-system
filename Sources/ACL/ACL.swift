import PgSQL
import Fluent
import Foundation

public protocol ACLType {
    static var namePrefix: String { get }
}

public enum ACLPosition: String, Codable, Sendable, CaseIterable {
    case right = "right"
    case left = "left"
}

public final class ACLExp<T: ACLType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.namePrefix + "_acl_exps" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let parentId = PGField("parent_id", .uuid)               .foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        public let ruleId = PGField("rule_id", .uuid)                   .required.foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        
        public let position = PGField("position", .enum(ACLPosition.self, as: "\(ACLExp<T>.name)_position"))
        
        public let type = PGField("type", .enum(AST.CodingType.self, as: "\(ACLExp<T>.name)_type"))
                                                                        .required
        
        public let op = PGField("operator", .enum(AST.Op.self, as: "\(ACLExp<T>.name)_operator"))
        
        public let value = PGField("value", .string)
        
        public let valueType = PGField("value_type", .enum(AST.ValueType.self, as: "\(ACLExp<T>.name)_value_type"))
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @OptionalParent(fields.parentId)                public var parent: ACLExp<T>?
    @Parent(fields.ruleId)                          public var rule: ACLExp<T>
    @OptionalEnum(fields.position)                  public var position: ACLPosition?
    @Enum(fields.type)                              public var type: AST.CodingType
    @OptionalEnum(fields.op)                        public var op: AST.Op?
    @Field(fields.value)                            public var value: String?
    @OptionalEnum(fields.valueType)                 public var valueType: AST.ValueType?
    
    public init() {}
    
    public typealias MIG = DefaultMIG<ACLExp<T>>
}
