import Fluent
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule

// MARK: - InfoSliceController Concurrency (InfoSliceController.swift)

extension PrivilegeSystem.InfoSliceController {
    public func create<T>(
        for infoId: UUID,
        extendedInfos: [PInfoSlice<T>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [QInfoSlice<T>] {
        try await create(for: infoId, extendedInfos: extendedInfos).get()
    }

    public func delete<T: UserInfoModel>(
        infoIds: [UUID],
        allSatisfy: Bool = true,
        type: T.Type = T.self
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(infoIds: infoIds, allSatisfy: allSatisfy, type: type).get()
    }

    public func update<T>(
        with updater: PInfoSlice<T>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QInfoSlice<T> {
        try await update(with: updater).get()
    }

    public func fetch(for userId: UUID) async throws(PrivilegeSystem.Errcase.ErrType) -> QExtendedInfo {
        try await fetch(for: userId).get()
    }
}
