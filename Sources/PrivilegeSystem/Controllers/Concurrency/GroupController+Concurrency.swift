import Foundation
import PrivilegeModule

// MARK: - GroupController Concurrency (GroupController.swift)

extension PrivilegeSystem.GroupController {
    // MARK: CRUD

    public func create(
        groups: OrderedSet<PGroup>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await create(groups: groups, on: transactor).get()
    }

    public func delete(
        groupIds: OrderedSet<UUID>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(groupIds: groupIds, on: transactor).get()
    }

    public func update(
        with updater: PGroup.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QGroup {
        try await update(with: updater, on: transactor).get()
    }

    // MARK: Join / Kick (result-builder variants)

    public func join(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        userToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(on: transactor, userToGroup: content).get()
    }
    
    public func join(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(on: transactor, content).get()
    }

    public func kick(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        userFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(on: transactor, userFromGroup: content).get()
    }

    public func kick(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QUser, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(on: transactor, content).get()
    }

    // MARK: Join / Kick (array variants)

    public func join(
        userToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(userToGroup: relations, on: transactor).get()
    }
    
    public func join(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(relations: relations, on: transactor).get()
    }

    public func kick(
        userFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(userFromGroup: relations, on: transactor).get()
    }

    public func kick(
        relations: OrderedSet<MTMRelation<QUser, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(relations: relations, on: transactor).get()
    }

    // MARK: Move

    public func move(
        _ relation: OTORelation<UUID, UUID?>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation, on: transactor).get()
    }
    
    public func move(
        _ relation: OTORelation<QGroup, QGroup?>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation, on: transactor).get()
    }

    // MARK: Query

    public func query(
        relations: OrderedSet<PUserTGroup>,
        strict: Bool = true,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UserTGroup] {
        try await query(relations: relations, strict: strict, on: transactor).get()
    }
}
