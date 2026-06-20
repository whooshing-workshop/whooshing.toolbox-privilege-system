import DTOBuilder
import Foundation

// MARK: - PrivilegeController Concurrency (PrivilegeController.swift)

public extension PrivilegeModule.PrivilegeController {
    // MARK: CRUD

    func create(
        privileges: OrderedSet<S.PPrivilege>
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await create(privileges: privileges).get()
    }

    func createWithReturning(
        privileges: OrderedSet<S.PPrivilege>
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.QPrivilege] {
        try await createWithReturning(privileges: privileges).get()
    }

    func delete(
        policy: S.QPrivilege
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(policy: policy).get()
    }

    func update(
        with updater: S.PPrivilege.Updater
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.QPrivilege {
        try await update(with: updater).get()
    }

    // MARK: Attach / Detach (result-builder overloads)

    func attach(
        @MTMRelationBuilder<UUID, UUID>
        privilegeToResource content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(privilegeToResource: content).get()
    }
    
    func attach(
        @MTMRelationBuilder<S.QPrivilege, AnyResource>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<S.QPrivilege, AnyResource>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(content).get()
    }
    
    func detach(
        @MTMRelationBuilder<UUID, UUID>
        privilegeFromResource content: @Sendable @escaping () -> OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(privilegeFromResource: content).get()
    }

    func detach(
        @MTMRelationBuilder<S.QPrivilege, AnyResource>
        _ content: @Sendable @escaping () -> OrderedSet<MTMRelation<S.QPrivilege, AnyResource>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(content).get()
    }

    // MARK: Attach / Detach (array overloads)

    func attach(
        privilegeToResource relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(privilegeToResource: relations).get()
    }
    
    func attach(
        relations: OrderedSet<MTMRelation<S.QPrivilege, AnyResource>>
    ) async throws(S.Errcase.ErrType) {
        try await attach(relations: relations).get()
    }

    func detach(
        privilegeFromResource relations: OrderedSet<MTMRelation<UUID, UUID>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(privilegeFromResource: relations).get()
    }
    
    func detach(
        relations: OrderedSet<MTMRelation<S.QPrivilege, AnyResource>>
    ) async throws(S.Errcase.ErrType) {
        try await detach(relations: relations).get()
    }

    // MARK: Privilege query

    func privilege<T: Resource>(
        attachedTo resource: S.QResource<T>
    ) async throws(Errcase.ErrType) -> [S.QPrivilege] {
        try await privilege(attachedTo: resource).get()
    }

    func privilege(
        attachedTo resource: AnyResource
    ) async throws(Errcase.ErrType) -> [S.QPrivilege] {
        try await privilege(attachedTo: resource).get()
    }

    // MARK: Is-attached check

    func `is`<T: Resource>(
        privilege: S.QPrivilege,
        attachedTo resource: S.QResource<T>
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource).get()
    }

    func `is`(
        privilege: S.QPrivilege,
        attachedTo resource: AnyResource
    ) async throws(Errcase.ErrType) -> Bool {
        try await self.is(privilege: privilege, attachedTo: resource).get()
    }
}
