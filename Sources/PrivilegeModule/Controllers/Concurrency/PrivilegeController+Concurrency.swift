import DTOBuilder
import Foundation

// MARK: - PrivilegeController Concurrency (PrivilegeController.swift)

public extension PrivilegeModule.PrivilegeController {
    // MARK: CRUD

    func create(
        privileges: OrderedSet<S.PPrivilege>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await create(privileges: privileges, on: transactor).get()
    }

    func createWithReturning(
        privileges: OrderedSet<S.PPrivilege>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.QPrivilege] {
        try await createWithReturning(privileges: privileges, on: transactor).get()
    }

    func delete(
        policy: S.QPrivilege,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(policy: policy, on: transactor).get()
    }

    @discardableResult
    func update(
        with updater: S.PPrivilege.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.QPrivilege {
        try await update(with: updater, on: transactor).get()
    }

    // MARK: Attach / Detach (result-builder overloads)

    func attach(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        privilegeToResource content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(on: transactor, privilegeToResource: content).get()
    }
    
    func attach(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<S.QPrivilege, GResource>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<S.QPrivilege, GResource>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(on: transactor, content).get()
    }
    
    func detach(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<UUID, UUID>
        privilegeFromResource content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(on: transactor, privilegeFromResource: content).get()
    }

    func detach(
        on transactor: Transactor? = nil,
        @MTMRelationBuilder<S.QPrivilege, GResource>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<S.QPrivilege, GResource>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(on: transactor, content).get()
    }

    // MARK: Attach / Detach (array overloads)

    func attach(
        privilegeToResource relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(S.Errcase.ErrType) {
        try await attach(privilegeToResource: relations, on: transactor).get()
    }
    
    func attach(
        relations: OrderedSet<MTMRelation<S.QPrivilege, GResource>>,
        on transactor: Transactor? = nil
    ) async throws(S.Errcase.ErrType) {
        try await attach(relations: relations, on: transactor).get()
    }

    func detach(
        privilegeFromResource relations: OrderedSet<MTMRelation<UUID, UUID>>,
        on transactor: Transactor? = nil
    ) async throws(S.Errcase.ErrType) {
        try await detach(privilegeFromResource: relations, on: transactor).get()
    }
    
    func detach(
        relations: OrderedSet<MTMRelation<S.QPrivilege, GResource>>,
        on transactor: Transactor? = nil
    ) async throws(S.Errcase.ErrType) {
        try await detach(relations: relations, on: transactor).get()
    }

    // MARK: Privilege query

    func privilege<T: Resource>(
        attachedTo resource: S.QResource<T>,
        on transactor: Transactor? = nil
    ) async throws(Errcase.ErrType) -> [S.QPrivilege] {
        try await privilege(attachedTo: resource, on: transactor).get()
    }

    func privilege(
        attachedTo resource: GResource,
        on transactor: Transactor? = nil
    ) async throws(Errcase.ErrType) -> [S.QPrivilege] {
        try await privilege(attachedTo: resource, on: transactor).get()
    }

    // MARK: Is-attached check

    func `is`<T: Resource>(
        privilege: S.QPrivilege,
        attachedTo resource: S.QResource<T>,
        on transactor: Transactor? = nil
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource, on: transactor).get()
    }

    func `is`(
        privilege: S.QPrivilege,
        attachedTo resource: GResource,
        on transactor: Transactor? = nil
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource, on: transactor).get()
    }
}
