import Foundation
import PrivilegeModule

extension __SDBM.Group {
    package final class Path: PGModel, @unchecked Sendable {
        
        package static let name = "group_paths"
        
        package struct Fields: PGFields {
            let id = PGField("id", .uuid)                           .primary
            let ancestorId = PGField("ancestor_id", .uuid)          .required.unique(composite: name + ".unique").foreign(__SDBM.Group.self, \.id, onDelete: .cascade)
            let descendantId = PGField("descendant_id", .uuid)      .required.unique(composite: name + ".unique").foreign(__SDBM.Group.self, \.id, onDelete: .cascade)
            let depth = PGField("depth", .int)                      .required
            
            package init() {}
        }
        
        package static let fields = Fields()
        
        @ID(key: .id)                                   package var id: UUID?
        
        @Parent(fields.ancestorId)                      package var ancestor: __SDBM.Group
        @Parent(fields.descendantId)                    package var descendant: __SDBM.Group
        
        @Field(fields.depth)                            package var depth: Int
        
        package init() {}
        
        package typealias MIG = DefaultMIG<Path>
    }

}
