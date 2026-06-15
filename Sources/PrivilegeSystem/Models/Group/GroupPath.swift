import PgSQL
import Fluent
import Foundation
import Policy
import PrivilegeModule

extension __SDBM.Group {
    final class Path: PGModel, @unchecked Sendable {
        
        static let name = "group_paths"
        
        struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let ancestorId = PGField("ancestor_id", .uuid)          .required.unique(composite: name + ".unique").foreign(__SDBM.Group.self, \.id, onDelete: .cascade)
            let descendantId = PGField("descendant_id", .uuid)      .required.unique(composite: name + ".unique").foreign(__SDBM.Group.self, \.id, onDelete: .cascade)
            let depth = PGField("depth", .int)                      .required
            
            init() {}
        }
        
        static let fields = Fields()
        
        @ID(key: .id)                                   var id: UUID?
        
        @Parent(fields.ancestorId)                      var ancestor: __SDBM.Group
        @Parent(fields.descendantId)                    var descendant: __SDBM.Group
        
        @Field(fields.depth)                            var depth: Int
        
        init() {}
        
        typealias MIG = DefaultMIG<Path>
    }

}
