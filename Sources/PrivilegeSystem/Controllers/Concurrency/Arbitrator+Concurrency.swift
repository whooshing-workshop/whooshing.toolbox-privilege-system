import Fluent
import Policy
import PgSQL
import NIOAdvanced
import OPA
import Foundation
import PrivilegeModule
import ResourceMacros
import OrderedCollections
@preconcurrency import AnyCodable

// MARK: - Arbitrator Concurrency (Arbitrator.swift)

extension PrivilegeSystem.Arbitrator {
    public func judge(
        moduleId: UUID,
        user: QUser,
        role: QRole,
        resource: AnyResource,
        operation: AnyOperation,
        privilegeIds: OrderedSet<UUID>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Result {
        try await judge(
            moduleId: moduleId,
            user: user,
            role: role,
            resource: resource,
            operation: operation,
            privilegeIds: privilegeIds
        ).get()
    }
    
    public func judge(
        moduleId: UUID,
        userId: UUID,
        roleId: UUID,
        resource: AnyResource,
        operation: AnyOperation,
        privilegeIds: OrderedSet<UUID>,
        logger: Logger
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Result {
        try await judge(
            moduleId: moduleId,
            userId: userId,
            roleId: roleId,
            resource: resource,
            operation: operation,
            privilegeIds: privilegeIds
        ).get()
    }
}
