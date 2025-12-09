import PgSQL
import Fluent
import Foundation

public protocol PivotType {
    associatedtype PrimaryModel: PGModel
    associatedtype SecondaryModel: PGModel
    
    static var foreignPrimaryName: String { get }
    static var foreignSecondaryName: String { get }
}

open class Pivot<T: PivotType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.foreignPrimaryName + "_" + T.foreignSecondaryName + "_map" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                                            .primary
        public let foreignPrimary = PGField(T.foreignPrimaryName + "_id", .uuid)        .required.unique(composite: name + ".pivot").foreign(T.PrimaryModel.self, .id, onDelete: .cascade)
        public let foreignSecondary = PGField(T.foreignSecondaryName + "_id", .uuid)    .required.unique(composite: name + ".pivot").foreign(T.SecondaryModel.self, .id, onDelete: .cascade)
        public let createdAt = PGField("create_at", .string)                            .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      public var id: UUID?
    
    @Parent(fields.foreignPrimary)                  public var primaryModel: T.PrimaryModel
    @Parent(fields.foreignSecondary)                public var secondaryModel: T.SecondaryModel
    
    @Timestamp(fields.createdAt, on: .create)       public var createdAt: Date!
    
    public required init() {}
    
    public typealias MIG = DefaultMIG<Pivot<T>>
}

public enum Pivots {}
