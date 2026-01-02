import PgSQL
import Fluent
import Foundation

public protocol ACLInterface: ACLType {
    var acl: ACLExp<Self> { get set }
    var map: Censor.Map { get set }
    var expression: String { get set }
}

public protocol ACLType {
    static var namePrefix: String { get }
}

public final class ACLExp<T: ACLType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.namePrefix + "_acl_exps" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let parentId = PGField("parent_id", .uuid)               .foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        public let ruleId = PGField("rule_id", .uuid)                   .required.foreign(ACLExp<T>.self, .id, onDelete: .cascade)
        public let position = PGField("position", .int)
        
        public let type = PGField(
            "type",
            .enum(Censor.AST.CodingType.self, as: "\(ACLExp<T>.name)_type")
        )                                                               .required
        
        public let op = PGField("operator", .string)
        public let value = PGField("value", .string)
        public let valueInt = PGField("value_int", .int64)
        public let valueDecimal = PGField("value_numeric", .custom("numeric"))
        
        public let valueType = PGField(
            "value_type",
            .enum(Censor.BasicType.self, as: "\(ACLExp<T>.name)_value_type")
        )
        
        public let valueNullable = PGField("value_nullable", .bool)
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @OptionalParent(fields.parentId)                public var parent: ACLExp<T>?
    @Parent(fields.ruleId)                          public var rule: ACLExp<T>
    @Field(fields.position)                         public var position: Int?
    @Enum(fields.type)                              public var type: Censor.AST.CodingType
    @Field(fields.op)                               public var op: String?
    @Field(fields.value)                            public var value: String?
    @Field(fields.valueInt)                         public var valueInt: Int64?
    @Field(fields.valueDecimal)                     public var valueDecimal: Decimal?
    @OptionalEnum(fields.valueType)                 public var valueType: Censor.BasicType?
    @Field(fields.valueNullable)                    public var valueNullable: Bool?
    
    public init() {}
    
    public typealias MIG = DefaultMIG<ACLExp<T>>
}
