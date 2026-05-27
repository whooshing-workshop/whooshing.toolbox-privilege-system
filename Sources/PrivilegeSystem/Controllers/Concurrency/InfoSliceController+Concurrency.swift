import Fluent
import PgSQL
import NIOAdvanced
import PrivilegeModule

// MARK: - InfoSliceController Concurrency (InfoSliceController.swift)

extension PrivilegeSystem.InfoSliceController {
    public func create<T>(
        for infoId: UUID,
        extendedInfos: [DTO.InfoSlice<T, DTO.Prepare>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [DTO.InfoSlice<T, DTO.Queried>] where T.Value == String {
        try await create(for: infoId, extendedInfos: extendedInfos).get()
    }

    public func delete<T: DTO.UserInfoModel>(
        infoIds: [UUID],
        allSatisfy: Bool = true,
        type: T.Type = T.self
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(infoIds: infoIds, allSatisfy: allSatisfy, type: type).get()
    }

    public func update<T>(
        with updater: DTO.InfoSlice<T, DTO.Prepare>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.InfoSlice<T, DTO.Queried> {
        try await update(with: updater).get()
    }

    public func fetch(for userId: UUID) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.ExtendedInfo<DTO.Queried> {
        try await fetch(for: userId).get()
    }
}
