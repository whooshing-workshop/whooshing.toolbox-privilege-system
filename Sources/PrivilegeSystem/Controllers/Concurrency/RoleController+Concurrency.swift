import Fluent
import Policy
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule

// MARK: - RoleController Concurrency (RoleController.swift)

extension PrivilegeSystem.RoleController {
    // MARK: Create (result-builder variants)

    public func create(
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () -> [MTORelation<PPolicy<Role>, PRole>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func createWithReturning(
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () -> [MTORelation<PPolicy<Role>, PRole>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(content).get()
    }

    // MARK: Create (array / scalar variants)

    public func create(
        roles: [PRole]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await create(roles: roles).get()
    }

    public func delete(
        roleIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(roleIds: roleIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: PRole.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QRole {
        try await update(with: updater).get()
    }

    // MARK: Create from relations

    public func create(
        relations: [MTORelation<PPolicy<Role>, PRole>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }

    public func createWithReturning(
        relations: [MTORelation<PPolicy<Role>, PRole>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(relations: relations).get()
    }

    // MARK: Appoint (result-builder variants)

    public func appoint(
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<QRole, QUserInGroupRelation>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    // MARK: Dismiss (result-builder variants)

    public func dismiss(
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<QRole, QUserInGroupRelation>
        _ content: @Sendable @escaping () -> [MTMRelation<QRole, QUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    // MARK: Appoint (array variants)

    public func appoint(
        relations: [MTMRelation<QRole, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<QRole, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<QRole, QUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<QRole, PUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    // MARK: Dismiss (array variants)

    public func dismiss(
        relations: [MTMRelation<QRole, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<QRole, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<QRole, QUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<QRole, PUserInGroupRelation>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    // MARK: Roles query

    public func roles(
        for user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await roles(for: user).get()
    }

    public func userRoles(
        for user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await userRoles(for: user).get()
    }

    public func groupRoles(
        for user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<QRole, QGroup>] {
        try await groupRoles(for: user).get()
    }

    public func userInGroupRoles(
        for user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<QRole, QGroup>] {
        try await userInGroupRoles(for: user).get()
    }

    // MARK: Is / Verify

    public func `is`(
        role: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(role: role, appointedTo: user).get()
    }

    public func `is`(
        userRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRole: userRole, appointedTo: user).get()
    }

    public func `is`(
        groupRole: QRole,
        appointedTo group: QGroup
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRole: groupRole, appointedTo: group).get()
    }

    public func verify(
        groupRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(groupRole: groupRole, appointedTo: user).get()
    }

    public func verify(
        userInGroupRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(userInGroupRole: userInGroupRole, appointedTo: user).get()
    }
}
