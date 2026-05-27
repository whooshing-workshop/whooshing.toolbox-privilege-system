import Fluent
import PgSQL
import ErrorHandle
import NIOAdvanced
import ResourceMacros

// MARK: - ResourceController Concurrency (ResourceController.swift)

public extension PrivilegeModule.ResourceController {
    typealias S = PM<ResourceList>

    func create<T: Resource>(
        resources: [S.ResourceDTO<T, DTO.Prepare>]
    ) async throws(PrivilegeModule.Errcase.ErrType) -> [S.ResourceDTO<T, DTO.Queried>] {
        try await create(resources: resources).get()
    }

    func delete(
        ids: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeModule.Errcase.ErrType) {
        try await delete(ids: ids, allSatisfy: allSatisfy).get()
    }

    func update<T: Resource>(
        with updater: S.ResourceDTO<T, DTO.Prepare>.Updater
    ) async throws(PrivilegeModule.Errcase.ErrType) -> S.ResourceDTO<T, DTO.Queried> {
        try await update(with: updater).get()
    }
}
