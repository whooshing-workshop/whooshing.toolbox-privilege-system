import Fluent
import Policy
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule
import OrderedCollections

// MARK: - RoleController Concurrency (RoleController.swift)

extension PrivilegeSystem.RoleController {
    // MARK: Create (result-builder variants)

    public func create(
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func createWithReturning(
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(content).get()
    }

    // MARK: Create (array / scalar variants)

    public func create(
        roles: OrderedSet<PRole>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await create(roles: roles).get()
    }

    public func delete(
        roleIds: OrderedSet<UUID>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(roleIds: roleIds).get()
    }

    public func update(
        with updater: PRole.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QRole {
        try await update(with: updater).get()
    }

    // MARK: Create from relations

    public func create(
        relations: OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }

    public func createWithReturning(
        relations: OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(relations: relations).get()
    }

    // MARK: Appoint (result-builder variants)

    public func appoint(
        @MTMRelationBuilder<UUID, UUID>
        roleToUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUser: content).get()
    }
    
    public func appoint(
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<UUID, UUID>
        roleToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToGroup: content).get()
    }
    
    public func appoint(
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<UUID, UUID>
        roleToUserInGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUserInGroup: content).get()
    }
    
    public func appoint(
        @MTMRelationBuilder<QRole, UserTGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, UserTGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    // MARK: Dismiss (result-builder variants)

    public func dismiss(
        @MTMRelationBuilder<UUID, UUID>
        roleFromUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUser: content).get()
    }
    
    public func dismiss(
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<UUID, UUID>
        roleFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromGroup: content).get()
    }
    
    public func dismiss(
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<UUID, UUID>
        roleFromUserInGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUserInGroup: content).get()
    }
    
    public func dismiss(
        @MTMRelationBuilder<QRole, UserTGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, UserTGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    // MARK: Appoint (array variants)

    public func appoint(
        roleToUser relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUser: relations).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        roleToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToGroup: relations).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        roleToUserInGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUserInGroup: relations).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, UserTGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    // MARK: Dismiss (array variants)

    public func dismiss(
        roleFromUser relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUser: relations).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        roleFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromGroup: relations).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        roleFromUserInGroup relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUserInGroup: relations).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, UserTGroup>>
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
        roleId: UUID,
        appointedTo userId: UUID
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(roleId: roleId, appointedTo: userId).get()
    }

    public func `is`(
        userRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRole: userRole, appointedTo: user).get()
    }
    
    public func `is`(
        userRoleId: UUID,
        appointedTo userId: UUID
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRoleId: userRoleId, appointedTo: userId).get()
    }

    public func `is`(
        groupRole: QRole,
        appointedTo group: QGroup
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRole: groupRole, appointedTo: group).get()
    }
    
    public func `is`(
        groupRoleId: UUID,
        appointedTo groupId: UUID
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRoleId: groupRoleId, appointedTo: groupId).get()
    }

    public func verify(
        groupRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(groupRole: groupRole, appointedTo: user).get()
    }
    
    public func verify(
        groupRoleId: UUID,
        appointedTo userId: UUID
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(groupRoleId: groupRoleId, appointedTo: userId).get()
    }

    public func verify(
        userInGroupRole: QRole,
        appointedTo user: QUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(userInGroupRole: userInGroupRole, appointedTo: user).get()
    }
    
    public func verify(
        userInGroupRoleId: UUID,
        appointedTo userId: UUID
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(userInGroupRoleId: userInGroupRoleId, appointedTo: userId).get()
    }
}
