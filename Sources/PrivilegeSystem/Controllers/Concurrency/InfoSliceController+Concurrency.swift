import Foundation
import PrivilegeModule

// MARK: - InfoSliceController Concurrency (InfoSliceController.swift)

extension PrivilegeSystem.InfoSliceController {
    public func create<T>(
        for infoId: UUID,
        extendedInfos: OrderedSet<PInfoSlice<T>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QInfoSlice<T>] {
        try await create(for: infoId, extendedInfos: extendedInfos).get()
    }

    public func delete<T: UserInfoModel>(
        infoIds: OrderedSet<UUID>,
        type: T.Type = T.self
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(infoIds: infoIds, type: type).get()
    }

    public func update<T>(
        with updater: PInfoSlice<T>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QInfoSlice<T> {
        try await update(with: updater).get()
    }
}
