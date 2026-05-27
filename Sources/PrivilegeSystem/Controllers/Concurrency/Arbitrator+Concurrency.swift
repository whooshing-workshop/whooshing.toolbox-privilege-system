import Fluent
import Policy
import PgSQL
import NIOAdvanced
import OPA
import PrivilegeModule
import ResourceMacros
@preconcurrency import AnyCodable

// MARK: - Arbitrator Concurrency (Arbitrator.swift)

extension PrivilegeSystem.Arbitrator {
    public func judge<T: Resource>(
        moduleId: UUID,
        user: DTO.User<DTO.Queried>,
        role: DTO.Role<DTO.Queried>,
        resource: T,
        operation: T.Operations,
        privilegeIds: [UUID]
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
}
