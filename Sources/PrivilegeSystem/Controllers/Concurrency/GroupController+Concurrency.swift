import Fluent
import Policy
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule

// MARK: - GroupController Concurrency (GroupController.swift)

extension PrivilegeSystem.GroupController {
    // MARK: CRUD

    public func create(
        groups: [PGroup]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await create(groups: groups).get()
    }

    public func delete(
        groupIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(groupIds: groupIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: PGroup.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QGroup {
        try await update(with: updater).get()
    }

    // MARK: Join / Kick (result-builder variants)

    public func join(
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QUser, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(content).get()
    }

    public func kick(
        @MTMRelationBuilder<QUser, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QUser, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(content).get()
    }

    // MARK: Join / Kick (array variants)

    public func join(
        relations: [MTMRelation<QUser, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await join(relations: relations).get()
    }

    public func kick(
        relations: [MTMRelation<QUser, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await kick(relations: relations).get()
    }

    // MARK: Move

    public func move(
        _ relation: OTORelation<QGroup, QGroup?>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await move(relation).get()
    }

    // MARK: Query

    public func query(
        relations: [PUserInGroupRelation],
        strict: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QUserInGroupRelation] {
        try await query(relations: relations, strict: strict).get()
    }
}
