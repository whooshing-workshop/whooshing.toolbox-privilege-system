import PgSQL
import Fluent
import Foundation
import Policy
import ErrorHandle

typealias A = Action
package extension PrivilegeModule {
    final class Action: PGModel, @unchecked Sendable {
        
        package static var name: String { "actions" }
        
        package struct Fields: PGFields {
            package let id = PGField("id", .uuid)                           .primary
            package let resourceType = PGField(
                "resource_type",
                .enum(ResourceList.self, as: "action.resource_type")
            )                                                               .required
                                                                            .unique(composite: "actions.unique")
            package let code = PGField("code", .int)                        .required
                                                                            .unique(composite: "actions.unique")
            package let name = PGField("name", .string)
            package let description = PGField("description", .string)
            
            package init() {}
        }
        
        package let fields = Fields()
        
        @ID(key: .id)                   package var id: UUID?
        
        @Enum(fields.resourceType)      package var type: ResourceList
        @Field(fields.code)             package var code: Int
        @Field(fields.name)             package var name: String?
        @Field(fields.description)      package var description: String?
        
        package init() { }
        
        init(
            type: ResourceList,
            name: String?,
            description: String?,
            code: Int
        ) {
            self.type = type
            self.name = name
            self.description = description
            self.code = code
        }
        
        func action<T: A>(as: T.Type = T.self) -> Res<T, Errcase> {
            guard let res = T.init(rawValue: self.code) else {
                return .failure(.actionCastFailed, category: .external)
            }
            
            return .success(res)
        }
        
        package typealias MIG = DefaultMIG<Action>
    }
}
