import Foundation
import PrivilegeModule

// MARK: - InfoSliceController Concurrency (InfoSliceController.swift)

extension PrivilegeSystem.InfoSliceController {
    @discardableResult
    public func create<T>(
        for infoId: UUID,
        extendedInfos: OrderedSet<PInfoSlice<T>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QInfoSlice<T>] {
        try await create(for: infoId, extendedInfos: extendedInfos, on: transactor).get()
    }

    public func delete<T: UserInfoModel>(
        infoIds: OrderedSet<UUID>,
        type: T.Type = T.self,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(infoIds: infoIds, type: type, on: transactor).get()
    }

    @discardableResult
    public func update<T>(
        with updater: PInfoSlice<T>.Updater,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QInfoSlice<T> {
        try await update(with: updater, on: transactor).get()
    }
}
