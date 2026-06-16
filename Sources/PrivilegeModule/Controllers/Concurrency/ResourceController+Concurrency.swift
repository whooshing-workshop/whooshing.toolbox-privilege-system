import Fluent
import PgSQL
import ErrorHandle
import NIOAdvanced
import Foundation
import ResourceMacros

// MARK: - ResourceController Concurrency (ResourceController.swift)

public extension PrivilegeModule.ResourceController {
    typealias S = PM<ResourceList>

    func create<T: Resource>(
        resources: [T]
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.QResource<T>] {
        try await create(resources: resources).get()
    }

    func delete(
        ids: [UUID]
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(ids: ids).get()
    }

    func update<T: Resource>(
        with updater: S.QResource<T>.Updater
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.QResource<T> {
        try await update(with: updater).get()
    }
}
