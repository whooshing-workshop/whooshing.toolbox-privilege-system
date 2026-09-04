import Vapor
import PrivilegeModuleExtended

public struct RoleAuthenticator: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        try await run(to: request, chainingTo: next)
    }
    
    func run(to request: Request, chainingTo next: any AsyncResponder) async throws(PrivilegeSystem.Errcase.ErrType) -> Response {
        guard
            let roleIdString = request.headers.first(name: "X-Role-Id"),
            let roleId = UUID(uuidString: roleIdString)
        else {
            throw PrivilegeSystem.Errcase.roleAuthenticationFailed.d("未找到有效的 'X-Role-Id' 请求头", category: .external(suggestions: ["请提供用户用于操作的角色身份"], userdata: .init(HTTPResponseStatus.unauthorized)))
        }
        
        guard
            let role = (try await required(throws: PrivilegeSystem.Errcase.roleAuthenticationFailed, "从数据库查询角色数据失败", category: .internal) {
                try await __SDBM.Role.query(on: request.db)
                    .filter(\.$id == roleId)
                    .first()
            })
        else {
            throw PrivilegeSystem.Errcase.roleAuthenticationFailed.d("角色不存在", category: .external(suggestions: ["请提供正确的角色身份"], userdata: .init(HTTPResponseStatus.unauthorized)))
        }
        
        let res = try required(throws: PrivilegeSystem.Errcase.roleAuthenticationFailed, "转为 RoleDTO 失败", category: .internal) {
            try QRole.make(from: role).get()
        }
        
        request.auth.login(res)
        
        return try await required(throws: PrivilegeSystem.Errcase.nextRespondFailed, category: .inherit) {
            try await next.respond(to: request)
        }
    }
}
