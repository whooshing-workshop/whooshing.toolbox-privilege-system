import Testing
import Foundation
@testable import PrivilegeSystem

// =============================================================================
// ReadmeExampleTests.swift
// =============================================================================
// 本测试套件专门用于验证 README 中的示例代码。
// =============================================================================

@Suite("README 示例 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct ReadmeExampleTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .readmeExamples {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    @Test("README 快速入门代码验证")
    func testQuickstart() async throws {
        // --- 1. 获取系统 ---
        // 注意：在实际应用中，您需要在应用启动时初始化 PrivilegeSystem。
        // 这里在测试中通过 TestingShared.getSystem() 获取已加载的系统。
        let (system, module) = try await TestingShared.getSystem()
        
        // --- 2. 创建用户 ---
        // 我们创建一个新用户。由于注册会直接返回 JWT Token 与用户资料，您可以借此获取 DTO
        let user = try await system.account.register(
            for: .init(
                email: "readme_user@example.com",
                hashedPassword: try Crypto.hash("SecurePassword123").get()
            )
        )
        
        // --- 3. 初始化权限模块与资源 ---
        // 模块在测试环境中已经通过 `TestingShared` 初始化，直接使用 `module`
        
        // 创建一个代表特定文档的资源 (假设这篇文档是 resource1)
        // 使用测试库自带的 `JsonResource` 结构
        let docResource = JsonResource(
            appId: "Secret_Doc",
            content: ["isPrivate": AnyCodable(true)]
        )
        let resourceDTO = try await module.resource.create(
            resources: [docResource]
        ).first!
        let anyResourceDTO = try #require(AnyResource(resourceDTO))
        
        // 创建一个简单的策略表达式。只要请求的操作是 "read"，就允许放行
        let myPolicy = """
        allow if {
            input.operation == "read"
        }
        """
        
        // 在系统内注册权限，并将其挂载至资源上
        let privilegeDTO = try await module.privilege.createWithReturning(
            privileges: [PM.PPrivilege(name: "doc_reader", summary: "Read documents", policy: myPolicy)]
        ).first!
        
        try await module.privilege.attach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        
        // --- 4. 创建角色并指派 ---
        // 创建名为 "Document Viewer" 的角色
        let role = try await system.role.create(
            roles: [.init(name: "Document Viewer", summary: "Can view docs")]
        ).first!
        
        // 为该角色分配此前定义的资源权限，注意我们也可以为角色单独编写一层附加的策略
        let rolePolicy = """
        allow if { true }
        """
        let rolePolicyDTO = PPolicy<Role>(moduleId: module.moduleId, policy: rolePolicy)
        let _ = try await system.policy.create(to: Role.self) {
            OrderedSet([rolePolicyDTO]) => role.id
        }
        
        // 最后，将该角色分配给用户
        try await system.role.appoint {
            OrderedSet([role]) => OrderedSet([user])
        }
        
        // --- 5. 执行权限仲裁 ---
        // 尝试对资源进行 `read` 操作
        let readResult = try await system.arbitrator.judge(
            moduleId: module.moduleId,
            user: user,
            role: role,
            resource: anyResourceDTO,
            operation: .init(op: JsonOperation(rawValue: "read")!),
            privilegeIds: [privilegeDTO.id]
        )
        #expect(readResult.result == true, "由于执行的是 'read' 并且符合策略，应当允许")
        
        // 尝试对资源进行 `write` 操作
        let writeResult = try await system.arbitrator.judge(
            moduleId: module.moduleId,
            user: user,
            role: role,
            resource: anyResourceDTO,
            operation: .init(op: JsonOperation(rawValue: "write")!),
            privilegeIds: [privilegeDTO.id]
        )
        #expect(writeResult.result == false, "策略中仅允许 read 操作，write 应当被拒绝")
        
        // --- 清理测试环境 ---
        try await system.role.dismiss {
            OrderedSet([role]) => OrderedSet([user])
        }
        try await system.role.delete(roleIds: [role.id])
        
        try await module.privilege.detach {
            OrderedSet([privilegeDTO]) => OrderedSet([anyResourceDTO])
        }
        try await module.privilege.delete(policy: privilegeDTO)
        try await module.resource.delete(ids: [resourceDTO.id])
        
        // Note: 删除用户操作尚未直接在 controller 提供，通过模型删除
        try await __SDBM.User.query(on: system.pgDB).filter(\.$id == user.id).delete()
    }

    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .init(rawValue: TestingShared.testStage.rawValue + 1)!
    }
}
