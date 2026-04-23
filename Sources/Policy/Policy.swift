import PgSQL
import Fluent
import Foundation

public protocol PolicyType: Sendable where Model.IDValue == UUID {
    associatedtype Model: PGModel
    static var namePrefix: String { get }
    static var typeId: String { get }
}

public final class PolicyExp<T: PolicyType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.namePrefix + "_policies" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let parentId = PGField("\(T.namePrefix)_id", .uuid)     .required
                                                                        .foreign(T.Model.self, .id, onDelete: .cascade)
        public let moduleId = PGField("module_id", .uuid)               .required
        public let policy = PGField("policy", .string)                  .required
        public let createdAt = PGField("created_at", .datetime)         .required
        public let updatedAt = PGField("updated_at", .datetime)         .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @Parent(fields.parentId)                        public var parent: T.Model
    @Field(fields.moduleId)                         public var moduleId: UUID
    @Field(fields.policy)                           public var policy: String
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    @Timestamp(fields.updatedAt, on: .update)       public var updatedAt: Date!
    
    public init() {}
    
    public typealias MIG = DefaultMIG<PolicyExp<T>>
}

extension PolicyExp: Hashable {
    public static func == (lhs: PolicyExp<T>, rhs: PolicyExp<T>) -> Bool {
        lhs.id == rhs.id &&
        lhs.$parent.id == rhs.$parent.id &&
        lhs.moduleId == rhs.moduleId &&
        lhs.policy == rhs.policy &&
        lhs.createdAt == rhs.createdAt &&
        lhs.updatedAt == rhs.updatedAt
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine($parent.id)
        hasher.combine(moduleId)
        hasher.combine(policy)
        hasher.combine(createdAt)
        hasher.combine(updatedAt)
    }
}

package enum PathFormat: Sendable {
    case path
    case route
    
    var prefix: String {
        switch self {
        case .path: "/"
        case .route: ""
        }
    }
    
    var sign: String {
        switch self {
        case .path: "/"
        case .route: "."
        }
    }
}

package func policyPath<PT: PolicyType>(
    moduleId: UUID,
    modelId: UUID,
    type: PT.Type = PT.self,
    format: PathFormat
) -> String {
    policyPath(moduleId: moduleId, modelId: modelId, type: PT.typeId, format: format)
}

package func policyPath(
    moduleId: UUID,
    modelId: UUID,
    type: String,
    format: PathFormat
) -> String {
    "\(format.prefix)m\(moduleId.hexString)\(format.sign)\(type)\(format.sign)id_\(modelId)"
}
