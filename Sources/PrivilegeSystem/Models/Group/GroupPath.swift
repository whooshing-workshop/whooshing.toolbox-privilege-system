import PgSQL
import Fluent
import Foundation
import Censor

extension UGroup {
    final class Path: PGModel, @unchecked Sendable {
        
        static let name = "group_paths"
        
        struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let ancestorId = PGField("ancestor_id", .uuid)          .required.unique(composite: name + ".unique").foreign(UGroup.self, \.id, onDelete: .cascade)
            let descendantId = PGField("descendant_id", .uuid)      .required.unique(composite: name + ".unique").foreign(UGroup.self, \.id, onDelete: .cascade)
            let depth = PGField("depth", .int)                      .required
            
            init() {}
        }
        
        static let fields = Fields()
        
        @ID(custom: fields.id.key)                      var id: UUID?
        
        @Parent(fields.ancestorId)                      var ancestor: UGroup
        @Parent(fields.descendantId)                    var descendant: UGroup
        
        @Field(fields.depth)                            var depth: Int
        
        init() {}
        
        typealias MIG = DefaultMIG<Path>
    }

}
