import Fluent
import Policy
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule

// MARK: - DomainController Concurrency (DomainController.swift)

extension PrivilegeSystem.DomainController {
    // MARK: Create (result-builder variants)

    public func create(
        @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func createWithReturning(
        @MTORelationBuilder<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [DTO.Policy<Domain, DTO.Queried>]] {
        try await createWithReturning(content).get()
    }

    public func create(
        domains: [DTO.Domain<DTO.Prepare>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.Domain<DTO.Queried>] {
        try await create(domains: domains).get()
    }

    public func delete(
        domainIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(domainIds: domainIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: DTO.Domain<DTO.Prepare>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.Domain<DTO.Queried> {
        try await update(with: updater).get()
    }

    // MARK: Relations (array variants)

    public func create(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }

    public func createWithReturning(
        relations: [MTORelation<DTO.Policy<Domain, DTO.Prepare>, DTO.Domain<DTO.Prepare>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [DTO.Policy<Domain, DTO.Queried>]] {
        try await createWithReturning(relations: relations).get()
    }

    // MARK: Assign (result-builder variants)

    public func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(content).get()
    }

    public func assign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(content).get()
    }

    // MARK: Unassign (result-builder variants)

    public func unassign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(content).get()
    }

    public func unassign(
        @MTMRelationBuilder<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>
        _ content: @Sendable @escaping () -> [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(content).get()
    }

    // MARK: Assign / Unassign (array variants)

    public func assign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations).get()
    }

    public func assign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations).get()
    }

    public func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.User<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations).get()
    }

    public func unassign(
        relations: [MTMRelation<DTO.Domain<DTO.Queried>, DTO.Group<DTO.Queried>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations).get()
    }
}
