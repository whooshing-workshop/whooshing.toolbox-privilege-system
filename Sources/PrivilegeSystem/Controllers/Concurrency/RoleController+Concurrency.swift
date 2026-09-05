import Foundation
import PrivilegeModule

// MARK: - RoleController Concurrency (RoleController.swift)

extension PrivilegeSystem.RoleController {
    // MARK: Create (result-builder variants)

    public func create(
        on transactor: Transactor? = nil,
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(on: transactor, content).get()
    }

    public func createWithReturning(
        on transactor: Transactor? = nil,
        @MTORelationBuilder<PPolicy<Role>, PRole>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Role>, PRole>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(on: transactor, content).get()
    }

    // MARK: Create (array / scalar variants)

    public func create(
        roles: OrderedSet<PRole>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await create(roles: roles, on: transactor).get()
    }

    public func delete(
        roleIds: OrderedSet<UUID>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(roleIds: roleIds, on: transactor).get()
    }

    @discardableResult
    public func update(
        with updater: PRole.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QRole {
        try await update(with: updater, on: transactor).get()
    }

    // MARK: Create from relations

    public func create(
        relations: OrderedSet<MTORelation<PPolicy<Role>, PRole>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations, on: transactor).get()
    }

    public func createWithReturning(
        relations: OrderedSet<MTORelation<PPolicy<Role>, PRole>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Role>]] {
        try await createWithReturning(relations: relations, on: transactor).get()
    }

    // MARK: Appoint (result-builder variants)

    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleToUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, roleToUser: content).get()
    }
    
    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, content).get()
    }

    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, roleToGroup: content).get()
    }
    
    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, content).get()
    }

    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleToUserInGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, roleToUserInGroup: content).get()
    }
    
    public func appoint(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, UserTGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, UserTGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(on: transactor, content).get()
    }

    // MARK: Dismiss (result-builder variants)

    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleFromUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, roleFromUser: content).get()
    }
    
    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, content).get()
    }

    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, roleFromGroup: content).get()
    }
    
    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, content).get()
    }

    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        roleFromUserInGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, roleFromUserInGroup: content).get()
    }
    
    public func dismiss(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QRole, UserTGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QRole, UserTGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(on: transactor, content).get()
    }

    // MARK: Appoint (array variants)

    public func appoint(
        roleToUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUser: relations, on: transactor).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, QUser>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations, on: transactor).get()
    }

    public func appoint(
        roleToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToGroup: relations, on: transactor).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations, on: transactor).get()
    }

    public func appoint(
        roleToUserInGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(roleToUserInGroup: relations, on: transactor).get()
    }
    
    public func appoint(
        relations: OrderedSet<MTMRelation<QRole, UserTGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations, on: transactor).get()
    }

    // MARK: Dismiss (array variants)

    public func dismiss(
        roleFromUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUser: relations, on: transactor).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, QUser>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations, on: transactor).get()
    }

    public func dismiss(
        roleFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromGroup: relations, on: transactor).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations, on: transactor).get()
    }

    public func dismiss(
        roleFromUserInGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(roleFromUserInGroup: relations, on: transactor).get()
    }
    
    public func dismiss(
        relations: OrderedSet<MTMRelation<QRole, UserTGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations, on: transactor).get()
    }
    
    // MARK: Roles query

    public func roles(
        for user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await roles(for: user, on: transactor).get()
    }

    public func userRoles(
        for user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QRole] {
        try await userRoles(for: user, on: transactor).get()
    }

    public func groupRoles(
        for user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<QRole, QGroup>] {
        try await groupRoles(for: user, on: transactor).get()
    }

    public func userInGroupRoles(
        for user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<QRole, QGroup>] {
        try await userInGroupRoles(for: user, on: transactor).get()
    }

    // MARK: Is / Verify

    public func `is`(
        role: QRole,
        appointedTo user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(role: role, appointedTo: user, on: transactor).get()
    }
    
    public func `is`(
        roleId: UUID,
        appointedTo userId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(roleId: roleId, appointedTo: userId, on: transactor).get()
    }

    public func `is`(
        userRole: QRole,
        appointedTo user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRole: userRole, appointedTo: user, on: transactor).get()
    }
    
    public func `is`(
        userRoleId: UUID,
        appointedTo userId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRoleId: userRoleId, appointedTo: userId, on: transactor).get()
    }

    public func `is`(
        groupRole: QRole,
        appointedTo group: QGroup,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRole: groupRole, appointedTo: group, on: transactor).get()
    }
    
    public func `is`(
        groupRoleId: UUID,
        appointedTo groupId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRoleId: groupRoleId, appointedTo: groupId, on: transactor).get()
    }

    public func verify(
        groupRole: QRole,
        appointedTo user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(groupRole: groupRole, appointedTo: user, on: transactor).get()
    }
    
    public func verify(
        groupRoleId: UUID,
        appointedTo userId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(groupRoleId: groupRoleId, appointedTo: userId, on: transactor).get()
    }

    public func verify(
        userInGroupRole: QRole,
        appointedTo user: QUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(userInGroupRole: userInGroupRole, appointedTo: user, on: transactor).get()
    }
    
    public func verify(
        userInGroupRoleId: UUID,
        appointedTo userId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QGroup] {
        try await verify(userInGroupRoleId: userInGroupRoleId, appointedTo: userId, on: transactor).get()
    }
}
