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
        @MTORelationBuilder<PPolicy<Domain>, PDomain>
        _ content: @Sendable @escaping () -> [MTORelation<PPolicy<Domain>, PDomain>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func createWithReturning(
        @MTORelationBuilder<PPolicy<Domain>, PDomain>
        _ content: @Sendable @escaping () -> [MTORelation<PPolicy<Domain>, PDomain>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Domain>]] {
        try await createWithReturning(content).get()
    }

    public func create(
        domains: [PDomain]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QDomain] {
        try await create(domains: domains).get()
    }

    public func delete(
        domainIds: [UUID],
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(domainIds: domainIds).get()
    }

    public func update(
        with updater: PDomain.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QDomain {
        try await update(with: updater).get()
    }

    // MARK: Relations (array variants)

    public func create(
        relations: [MTORelation<PPolicy<Domain>, PDomain>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }

    public func createWithReturning(
        relations: [MTORelation<PPolicy<Domain>, PDomain>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Domain>]] {
        try await createWithReturning(relations: relations).get()
    }

    // MARK: Assign (result-builder variants)

    public func assign(
        @MTMRelationBuilder<UUID, UUID>
        domainToUser content: @Sendable @escaping () -> [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToUser: content).get()
    }
    
    public func assign(
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> [MTMRelation<QDomain, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(content).get()
    }

    public func assign(
        @MTMRelationBuilder<UUID, UUID>
        domainToGroup content: @Sendable @escaping () -> [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToGroup: content).get()
    }
    
    public func assign(
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QDomain, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(content).get()
    }

    // MARK: Unassign (result-builder variants)

    public func unassign(
        @MTMRelationBuilder<UUID, UUID>
        domainFromUser content: @Sendable @escaping () -> [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromUser: content).get()
    }
    
    public func unassign(
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> [MTMRelation<QDomain, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(content).get()
    }

    public func unassign(
        @MTMRelationBuilder<UUID, UUID>
        domainFromGroup content: @Sendable @escaping () -> [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromGroup: content).get()
    }
    
    public func unassign(
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> [MTMRelation<QDomain, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(content).get()
    }

    // MARK: Assign / Unassign (array variants)

    public func assign(
        domainToUser relations: [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToUser: relations).get()
    }
    
    public func assign(
        relations: [MTMRelation<QDomain, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations).get()
    }

    public func assign(
        domainToGroup relations: [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToGroup: relations).get()
    }
    
    public func assign(
        relations: [MTMRelation<QDomain, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations).get()
    }

    public func unassign(
        domainFromUser relations: [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromUser: relations).get()
    }
    
    public func unassign(
        relations: [MTMRelation<QDomain, QUser>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations).get()
    }

    public func unassign(
        domainFromGroup relations: [MTMRelation<UUID, UUID>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromGroup: relations).get()
    }
    
    public func unassign(
        relations: [MTMRelation<QDomain, QGroup>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations).get()
    }
}
