import DTOBuilder
import Foundation

// MARK: - ResourceController Concurrency (ResourceController.swift)

public extension PrivilegeModule.ResourceController {
    typealias S = PM<ResourceList>

    @discardableResult
    func create<T: Resource>(
        resources: OrderedSet<T>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.QResource<T>] {
        try await create(resources: resources, on: transactor).get()
    }
    
    @discardableResult
    func create(
        resources: OrderedSet<AnyResource>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [GResource] {
        try await create(resources: resources, on: transactor).get()
    }

    func delete(
        ids: OrderedSet<UUID>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(ids: ids, on: transactor).get()
    }

    @discardableResult
    func update<T: Resource>(
        with updater: S.QResource<T>.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.QResource<T> {
        try await update(with: updater, on: transactor).get()
    }
}
