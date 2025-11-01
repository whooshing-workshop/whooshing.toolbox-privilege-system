import PgSQL
import SQLKit
import Fluent
import Foundation

final class Role: PGModel, @unchecked Sendable {
    
    static let name = "roles"
    
    struct Fields: PGFields {
        
        let id = PGField("id", .uuid)                           .primary
        let aclId = PGField("acl_id", .uuid)                    .foreign(ACL.self, \.id, onDelete: .cascade)
        let ast = PGField("ast", .json)                         .required.def(" '{}'::jsonb ")
        let name = PGField("name", .string)                     .required
        let description = PGField("description", .string)
        let createdAt = PGField("create_at", .string)           .required
        let updateAt = PGField("update_at", .string)            .required
        
        init() {}
    }
    
    static let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: UUID?
    
    @Parent(fields.aclId)                           var acl: ACL
    @Field(fields.ast)                              var ast: AST
    @Field(fields.name)                             var name: String
    @Field(fields.description)                      var description: String?
    
    @Siblings(
        through: UserRolePivot.self,
        from: \.$role,
        to: \.$user
    )                                               var users: [User]
    @Siblings(
        through: RoleGroupPivot.self,
        from: \.$role,
        to: \.$group
    )                                               var groups: [UGroup]
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    init() {}
}

extension Role {
    @usableFromInline
    struct MIG: PGMigration, Sendable {
        @usableFromInline
        typealias DataModel = Role
        
        @usableFromInline
        var tdeEncrypt: Bool
        
        @inlinable
        init(tdeEncrypt: Bool = true) {
            self.tdeEncrypt = tdeEncrypt
        }
    }
}

extension Role {
    indirect enum AST: Codable {
        case variable(String)
        case number(Double)
        case string(String)
        case binary(op: String, left: Self, right: Self)

        enum CodingKeys: String, CodingKey {
            case type, value, op, left, right
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(String.self, forKey: .type)

            switch type {
            case "variable":
                let value = try c.decode(String.self, forKey: .value)
                self = .variable(value)

            case "number":
                let value = try c.decode(Double.self, forKey: .value)
                self = .number(value)

            case "string":
                let value = try c.decode(String.self, forKey: .value)
                self = .string(value)

            case "binary":
                let op = try c.decode(String.self, forKey: .op)
                let left = try c.decode(Self.self, forKey: .left)
                let right = try c.decode(Self.self, forKey: .right)
                self = .binary(op: op, left: left, right: right)

            default:
                preconditionFailure("未知的 AST 类型: \(type)")
            }
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .variable(let v):
                try c.encode("variable", forKey: .type)
                try c.encode(v, forKey: .value)

            case .number(let v):
                try c.encode("number", forKey: .type)
                try c.encode(v, forKey: .value)

            case .string(let v):
                try c.encode("string", forKey: .type)
                try c.encode(v, forKey: .value)

            case .binary(let op, let left, let right):
                try c.encode("binary", forKey: .type)
                try c.encode(op, forKey: .op)
                try c.encode(left, forKey: .left)
                try c.encode(right, forKey: .right)
            }
        }
    }
}
