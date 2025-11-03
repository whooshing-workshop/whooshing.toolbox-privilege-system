import PgSQL
import Fluent
import Foundation

protocol PivotType {
    associatedtype PrimaryModel: PGModel
    associatedtype SecondaryModel: PGModel
    
    static var foreignPrimaryName: String { get }
    static var foreignSecondaryName: String { get }
}

class Pivot<T: PivotType>: PGModel, @unchecked Sendable {
    
    static var name: String { T.foreignPrimaryName + "_" + T.foreignSecondaryName + "_map" }
    
    struct Fields: PGFields {
        let id = PGField("id", .uuid)                                           .primary
        let foreignPrimary = PGField(T.foreignPrimaryName + "_id", .uuid)       .required.unique(composite: name + ".pivot").foreign(T.PrimaryModel.self, .id, onDelete: .cascade)
        let foreignSecondary = PGField(T.foreignSecondaryName + "_id", .uuid)   .required.unique(composite: name + ".pivot").foreign(T.SecondaryModel.self, .id, onDelete: .cascade)
        let createdAt = PGField("create_at", .string)                           .required
        let updateAt = PGField("update_at", .string)                            .required
        
        init() {}
    }
    
    let fields = Fields()
    
    @ID(custom: fields.id.key)                      var id: Int?
    
    @Parent(fields.foreignPrimary)                  var primaryModel: T.PrimaryModel
    @Parent(fields.foreignSecondary)                var secondaryModel: T.SecondaryModel
    
    @Timestamp(fields.createdAt, on: .create)       var createdAt: Date!
    @Timestamp(fields.updateAt, on: .update)        var updatedAt: Date!
    
    required init() {}
    
    typealias MIG = DefaultMIG<Pivot<T>>
}

enum Pivots {}
