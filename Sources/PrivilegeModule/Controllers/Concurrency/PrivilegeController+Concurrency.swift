import Fluent
import Policy
import PgSQL
import ErrorHandle
import NIOAdvanced
import OPA
import ResourceMacros

// MARK: - PrivilegeController Concurrency (PrivilegeController.swift)

public extension PrivilegeModule.PrivilegeController {
    // MARK: CRUD

    func create(
        privileges: [S.PrivilegeDTO<DTO.Prepare>]
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await create(privileges: privileges).get()
    }

    func createWithReturning(
        privileges: [S.PrivilegeDTO<DTO.Prepare>]
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.PrivilegeDTO<DTO.Queried>] {
        try await createWithReturning(privileges: privileges).get()
    }

    func delete(
        policy: S.PrivilegeDTO<DTO.Queried>
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(policy: policy).get()
    }

    func update(
        with updater: S.PrivilegeDTO<DTO.Prepare>.Updater
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.PrivilegeDTO<DTO.Queried> {
        try await update(with: updater).get()
    }

    // MARK: Attach / Detach (result-builder overloads)

    func attach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) async throws(S.Errcase.ErrType) {
        try await attach(content).get()
    }

    func detach(
        @MTMRelationBuilder<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>
        _ content: @Sendable @escaping () -> [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) async throws(S.Errcase.ErrType) {
        try await detach(content).get()
    }

    // MARK: Attach / Detach (array overloads)

    func attach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) async throws(S.Errcase.ErrType) {
        try await attach(relations: relations).get()
    }

    func detach(
        relations: [MTMRelation<S.PrivilegeDTO<DTO.Queried>, S.AnyResourceDTO>]
    ) async throws(S.Errcase.ErrType) {
        try await detach(relations: relations).get()
    }

    // MARK: Privilege query

    func privilege<T: Resource>(
        attachedTo resource: S.ResourceDTO<T, DTO.Queried>
    ) async throws(Errcase.ErrType) -> [S.PrivilegeDTO<DTO.Queried>] {
        try await privilege(attachedTo: resource).get()
    }

    func privilege(
        attachedTo resource: S.AnyResourceDTO
    ) async throws(Errcase.ErrType) -> [S.PrivilegeDTO<DTO.Queried>] {
        try await privilege(attachedTo: resource).get()
    }

    // MARK: Is-attached check

    func `is`<T: Resource>(
        privilege: S.PrivilegeDTO<DTO.Queried>,
        attachedTo resource: S.ResourceDTO<T, DTO.Queried>
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource).get()
    }

    func `is`(
        privilege: S.PrivilegeDTO<DTO.Queried>,
        attachedTo resource: S.AnyResourceDTO
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource).get()
    }
}
