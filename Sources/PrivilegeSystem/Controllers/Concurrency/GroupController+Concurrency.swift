import Foundation
import PrivilegeModule

// MARK: - GroupController Concurrency (GroupController.swift)

extension PrivilegeSystem.GroupController {
    // MARK: CRUD

    public func create(
        groups: OrderedSet<PGroup>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await create(groups: groups).get()
    }

    public func delete(
        groupIds: OrderedSet<UUID>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(groupIds: groupIds).get()
    }

    public func update(
        with updater: PGroup.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QGroup {
        try await update(with: updater).get()
    }

    // MARK: Join / Kick (result-builder variants)

    public func join(
        @MTMRelationBuilder<UUID, UUID>
        userToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(userToGroup: content).get()
    }
    
    public func join(
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(content).get()
    }

    public func kick(
        @MTMRelationBuilder<UUID, UUID>
        userFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(userFromGroup: content).get()
    }

    public func kick(
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(content).get()
    }

    // MARK: Join / Kick (array variants)

    public func join(
        userToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(userToGroup: relations).get()
    }
    
    public func join(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(relations: relations).get()
    }

    public func kick(
        userFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(userFromGroup: relations).get()
    }

    public func kick(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(relations: relations).get()
    }

    // MARK: Move

    public func move(
        _ relation: OTORelation<UUID, UUID?>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation).get()
    }
    
    public func move(
        _ relation: OTORelation<QGroup, QGroup?>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation).get()
    }

    // MARK: Query

    public func query(
        relations: OrderedSet<PUserTGroup>,
        strict: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UserTGroup] {
        try await query(relations: relations, strict: strict).get()
    }
}
