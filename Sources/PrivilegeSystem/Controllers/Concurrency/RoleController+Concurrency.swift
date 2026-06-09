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
        @MTORelationBuilder<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func createWithReturning(
        @MTORelationBuilder<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [DTO.Policy<Role, DTO.Queried>]] {
        try await createWithReturning(content).get()
    }

    // MARK: Create (array / scalar variants)

    public func create(
        roles: [DTO.Role<DTO.Prepare>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Role<DTO.Queried>] {
        try await create(roles: roles).get()
    }

    public func delete(
        roleIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(roleIds: roleIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: DTO.Role<DTO.Prepare>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.Role<DTO.Queried> {
        try await update(with: updater).get()
    }

    // MARK: Create from relations

    public func create(
        relations: [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }

    public func createWithReturning(
        relations: [MTORelation<DTO.Policy<Role, DTO.Prepare>, DTO.Role<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [DTO.Policy<Role, DTO.Queried>]] {
        try await createWithReturning(relations: relations).get()
    }

    // MARK: Appoint (result-builder variants)

    public func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    public func appoint(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(content).get()
    }

    // MARK: Dismiss (result-builder variants)

    public func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    public func dismiss(
        @MTMRelationBuilder<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(content).get()
    }

    // MARK: Appoint (array variants)

    public func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    public func appoint(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await appoint(relations: relations).get()
    }

    // MARK: Dismiss (array variants)

    public func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    public func dismiss(
        relations: [MTMRelation<DTO.Role<DTO.Queried>, DTO.UserInGroupRelation<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await dismiss(relations: relations).get()
    }

    // MARK: Roles query

    public func roles(
        for user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Role<DTO.Queried>] {
        try await roles(for: user).get()
    }

    public func userRoles(
        for user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Role<DTO.Queried>] {
        try await userRoles(for: user).get()
    }

    public func groupRoles(
        for user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>] {
        try await groupRoles(for: user).get()
    }

    public func userInGroupRoles(
        for user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [MTORelation<DTO.Role<DTO.Queried>, DTO.Group<DTO.Queried>>] {
        try await userInGroupRoles(for: user).get()
    }

    // MARK: Is / Verify

    public func `is`(
        role: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(role: role, appointedTo: user).get()
    }

    public func `is`(
        userRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(userRole: userRole, appointedTo: user).get()
    }

    public func `is`(
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo group: DTO.Group<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Bool {
        try await self.is(groupRole: groupRole, appointedTo: group).get()
    }

    public func verify(
        groupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Group<DTO.Queried>] {
        try await verify(groupRole: groupRole, appointedTo: user).get()
    }

    public func verify(
        userInGroupRole: DTO.Role<DTO.Queried>,
        appointedTo user: DTO.User<DTO.Queried>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Group<DTO.Queried>] {
        try await verify(userInGroupRole: userInGroupRole, appointedTo: user).get()
    }
}
