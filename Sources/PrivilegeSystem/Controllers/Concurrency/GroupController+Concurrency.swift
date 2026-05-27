import Fluent
import Policy
import PgSQL
import NIOAdvanced
import PrivilegeModule

// MARK: - GroupController Concurrency (GroupController.swift)

extension PrivilegeSystem.GroupController {
    // MARK: CRUD

    public func create(
        groups: [DTO.Group<DTO.Prepare>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Group<DTO.Queried>] {
        try await create(groups: groups).get()
    }

    public func delete(
        groupIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(groupIds: groupIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: DTO.Group<DTO.Prepare>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.Group<DTO.Queried> {
        try await update(with: updater).get()
    }

    // MARK: Join / Kick (result-builder variants)

    public func join(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(content).get()
    }

    public func kick(
        @MTMRelationBuilder<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(content).get()
    }

    // MARK: Join / Kick (array variants)

    public func join(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(relations: relations).get()
    }

    public func kick(
        relations: [MTMRelation<DTO.User<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(relations: relations).get()
    }

    // MARK: Move

    public func move(
        _ relation: OTORelation<DTO.Group<DTO.Queried>, DTO.Group<DTO.Queried>?>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation).get()
    }

    // MARK: Query

    public func query(
        relations: [DTO.UserInGroupRelation<DTO.Prepare>],
        strict: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.UserInGroupRelation<DTO.Queried>] {
        try await query(relations: relations, strict: strict).get()
    }
}
