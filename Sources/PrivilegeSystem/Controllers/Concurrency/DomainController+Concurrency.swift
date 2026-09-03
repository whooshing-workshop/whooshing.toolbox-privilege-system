import Foundation
import PrivilegeModule

// MARK: - DomainController Concurrency (DomainController.swift)

extension PrivilegeSystem.DomainController {
    // MARK: Create (result-builder variants)

    public func create(
        on transactor: Transactor? = nil,
        @MTORelationBuilder<PPolicy<Domain>, PDomain>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(on: transactor, content).get()
    }

    public func createWithReturning(
        on transactor: Transactor? = nil,
        @MTORelationBuilder<PPolicy<Domain>, PDomain>
        _ content: @Sendable @escaping () ->OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Domain>]] {
        try await createWithReturning(on: transactor, content).get()
    }

    public func create(
        domains: OrderedSet<PDomain>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QDomain] {
        try await create(domains: domains, on: transactor).get()
    }

    public func delete(
        domainIds: OrderedSet<UUID>,
    on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(domainIds: domainIds, on: transactor).get()
    }

    public func update(
        with updater: PDomain.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QDomain {
        try await update(with: updater, on: transactor).get()
    }

    // MARK: Relations (array variants)

    public func create(
        relations: OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations, on: transactor).get()
    }

    public func createWithReturning(
        relations: OrderedSet<MTORelation<PPolicy<Domain>, PDomain>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [UUID: [QPolicy<Domain>]] {
        try await createWithReturning(relations: relations, on: transactor).get()
    }

    // MARK: Assign (result-builder variants)

    public func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainToUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(on: transactor, domainToUser: content).get()
    }
    
    public func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(on: transactor, content).get()
    }

    public func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainToGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(on: transactor, domainToGroup: content).get()
    }
    
    public func assign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(on: transactor, content).get()
    }

    // MARK: Unassign (result-builder variants)

    public func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainFromUser content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(on: transactor, domainFromUser: content).get()
    }
    
    public func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QUser>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QUser>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(on: transactor, content).get()
    }

    public func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        domainFromGroup content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(on: transactor, domainFromGroup: content).get()
    }
    
    public func unassign(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<QDomain, QGroup>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<QDomain, QGroup>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(on: transactor, content).get()
    }

    // MARK: Assign / Unassign (array variants)

    public func assign(
        domainToUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToUser: relations, on: transactor).get()
    }
    
    public func assign(
        relations: OrderedSet<MTMRelation<QDomain, QUser>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations, on: transactor).get()
    }

    public func assign(
        domainToGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(domainToGroup: relations, on: transactor).get()
    }
    
    public func assign(
        relations: OrderedSet<MTMRelation<QDomain, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await assign(relations: relations, on: transactor).get()
    }

    public func unassign(
        domainFromUser relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromUser: relations, on: transactor).get()
    }
    
    public func unassign(
        relations: OrderedSet<MTMRelation<QDomain, QUser>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations, on: transactor).get()
    }

    public func unassign(
        domainFromGroup relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(domainFromGroup: relations, on: transactor).get()
    }
    
    public func unassign(
        relations: OrderedSet<MTMRelation<QDomain, QGroup>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await unassign(relations: relations, on: transactor).get()
    }
}
