import PgSQL
import Fluent
import Foundation

public protocol PivotType: Hashable, Sendable {
    associatedtype PrimaryModel: PGModel
    associatedtype SecondaryModel: PGModel
    
    static var foreignPrimaryName: String { get }
    static var foreignSecondaryName: String { get }
    
    static var foreignPrimaryType: DatabaseSchema.DataType { get }
    static var foreignSecondaryType: DatabaseSchema.DataType { get }
}

public extension PivotType {
    static var foreignPrimaryType: DatabaseSchema.DataType { .uuid }
    static var foreignSecondaryType: DatabaseSchema.DataType { .uuid }
}

open class Pivot<T: PivotType>: PGModel, @unchecked Sendable {
    
    public static var name: String { T.foreignPrimaryName + "_" + T.foreignSecondaryName + "_map" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let foreignPrimary = PGField(
            T.foreignPrimaryName + "_id", T.foreignPrimaryType
        )                                                               .required
                                                                        .unique(composite: name + ".pivot")
                                                                        .foreign(T.PrimaryModel.self, .id, onDelete: .cascade)
        public let foreignSecondary = PGField(
            T.foreignSecondaryName + "_id", T.foreignSecondaryType
        )                                                               .required
                                                                        .unique(composite: name + ".pivot")
                                                                        .foreign(T.SecondaryModel.self, .id, onDelete: .cascade)
        public let createdAt = PGField("created_at", .datetime)         .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    @ID(key: .id)                                   open var id: UUID?
    
    @Parent(fields.foreignPrimary)                  open var primaryModel: T.PrimaryModel
    @Parent(fields.foreignSecondary)                open var secondaryModel: T.SecondaryModel
    
    @Timestamp(fields.createdAt, on: .create)       open var createdAt: Date!
    
    public required init() {}
    
    public typealias MIG = DefaultMIG<Pivot<T>>
}

extension Pivot: Hashable {
    public static func == (lhs: Pivot<T>, rhs: Pivot<T>) -> Bool {
        lhs.id == rhs.id &&
        lhs.$primaryModel.id == rhs.$primaryModel.id &&
        lhs.$secondaryModel.id == rhs.$secondaryModel.id &&
        lhs.createdAt == rhs.createdAt
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine($primaryModel.id)
        hasher.combine($secondaryModel.id)
        hasher.combine(createdAt)
    }
}

open class CustomeIDPivot<T: PivotType>: @unchecked Sendable {
    
    public static var name: String { T.foreignPrimaryName + "_" + T.foreignSecondaryName + "_map" }
    
    public struct Fields: PGFields {
        public let id = PGField("id", .uuid)                            .primary
        public let foreignPrimary = PGField(
            T.foreignPrimaryName + "_id", T.foreignPrimaryType
        )                                                               .required
                                                                        .unique(composite: name + ".pivot")
                                                                        .foreign(T.PrimaryModel.self, .id, onDelete: .cascade)
        public let foreignSecondary = PGField(
            T.foreignSecondaryName + "_id", T.foreignSecondaryType
        )                                                               .required
                                                                        .unique(composite: name + ".pivot")
                                                                        .foreign(T.SecondaryModel.self, .id, onDelete: .cascade)
        public let createdAt = PGField("created_at", .datetime)         .required
        
        public init() {}
    }
    
    let fields = Fields()
    
    public required init() {}
    
    public typealias MIG = DefaultMIG<Pivot<T>>
}

public enum __SDBM {
    public enum Pivots {}
}
