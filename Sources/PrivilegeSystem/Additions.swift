import NIOHTTP1
import Foundation
import PrivilegeModuleExtended

public extension PrivilegeSystem {
    func createAdminIfNotExist(
        using role: PRole = .init(name: "admin", summary: "系统最高管理者"),
        to moduleId: UUID,
        for user: PUser,
        on transactor: Transactor? = nil
    ) -> EventLoopRes<QUser?, Errcase> {
        let logger = self.logger.derive(subId: "create_admin", metadata: ["role": .summaryData(role), "user": .summaryData(user), "module_id": .summaryData(moduleId)])
        logger.info("检查角色是否存在")
        let trans = transactor ?? self.origin
        return trans.trans(throws: Errcase.adminCreateFailed, "事务执行失败", category: .inherit) { t in
            QRole.query(on: t)
                .filter(\.name == role.name)
                .first()
                .errCast(Errcase.adminCreateFailed, "从数据库查询 Role 失败", category: .internal)
                .flatMap
            { (r: QRole?) -> EventLoopRes<QRole, Errcase> in
                if let role = r {
                    self.logger.info("角色已存在，无需创建")
                    return t.eventLoop.makeSucceededResult(role)
                } else {
                    self.logger.info("角色不存在，正在创建")
                    return self.role.create(roles: [role], on: t).flatMap { r in
                        guard let role = r.first else {
                            return t.eventLoop.makeFailedResult(Errcase.adminCreateFailed, category: .internal)
                        }
                        return t.eventLoop.makeSucceededResult(role)
                    }.flatMap { (role: QRole) in
                        self.logger.info("正在创建 admin 权限")
                        let policy = PPolicy<Role>(moduleId: moduleId, policy: "allow if { true }")
                        return self.policy.create(on: t, to: Role.self) {
                            OrderedSet([policy]) => role.id
                        }.map { _ in role }
                    }
                }
            }.flatMap { (role: QRole) -> EventLoopRes<QUser?, Errcase> in
                self.logger.info("正在检查用户是否存在")
                return QUser.query(on: t)
                    .filter(\.email == user.email)
                    .first()
                    .errCast(Errcase.adminCreateFailed, "从数据库查询 User 失败", category: .internal)
                    .flatMap
                { u -> EventLoopRes<QUser?, Errcase> in
                    if u != nil {
                        self.logger.info("用户已存在，无需创建")
                        return t.eventLoop.makeSucceededResult(nil)
                    } else {
                        self.logger.info("正在创建管理员用户")
                        return self.account.register(for: user, on: t).flatMap { u in
                            self.role.appoint(on: t) {
                                OrderedSet([role]) => OrderedSet([u])
                            }.map { u }
                        }.map {
                            self.logger.info("管理员用户创建成功")
                            return $0
                        }
                    }
                }
            }
        }
    }
    
    func createNobodyIfNotExist(roleId: UUID? = nil, on transactor: Transactor? = nil) -> EventLoopRes<QRole?, Errcase> {
        let logger = self.logger.derive(subId: "create_nobody")
        logger.info("检查用户是否存在")
        let trans = transactor ?? self.origin
        return trans.trans(throws: Errcase.nobodyRoleCreateFailed, "事务执行失败", category: .inherit) { t in
            QRole.query(on: t)
                .filter(\.name == "nobody")
                .first()
                .errCast(Errcase.nobodyRoleCreateFailed, category: .internal)
                .flatMap
            { r -> EventLoopRes<QRole?, Errcase> in
                if let role = r {
                    self.logger.info("角色已存在，无需创建")
                    if let rId = roleId, rId != role.id {
                        return t.eventLoop.makeFailedResult(Errcase.nobodyRoleCreateFailed.d("所要指定创建的角色 ID 与原有角色冲突", category: .external(suggestions: ["尝试使用随机 ID 创建 nobody 角色", "或指定正确的 ID"], userdata: .init(HTTPResponseStatus.conflict))))
                    }
                    self.account.nobodyRoleId = role.id
                    return t.eventLoop.makeSucceededResult(nil)
                } else {
                    self.logger.info("用户不存在，正在创建")
                    let role = PRole(id: roleId, name: "nobody", summary: "最基本无权限角色")
                    return self.role.create(roles: [role], on: t).flatMap { rs in
                        guard let role = rs.first else {
                            return t.eventLoop.makeFailedResult(Errcase.nobodyRoleCreateFailed, "将角色创建与数据库时失败", category: .internal)
                        }
                        self.account.nobodyRoleId = role.id
                        return t.eventLoop.makeSucceededResult(role).map {
                            self.logger.info("nobody 角色创建成功")
                            return $0
                        }
                    }
                }
            }
        }
    }
}

public extension PrivilegeSystem {
    @discardableResult
    func createAdminIfNotExist(
        using role: PRole = .init(name: "admin", summary: "系统最高管理者"),
        to moduleId: UUID,
        for user: PUser,
        on transactor: Transactor? = nil
    ) async throws(Errcase.ErrType) -> QUser? {
        try await createAdminIfNotExist(using: role, to: moduleId, for: user, on: transactor).get()
    }
    
    @discardableResult
    func createNobodyIfNotExist(roleId: UUID? = nil, on transactor: Transactor? = nil) async throws(Errcase.ErrType) -> QRole? {
        try await createNobodyIfNotExist(roleId: roleId, on: transactor).get()
    }
}
