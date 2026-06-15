import Fluent
import PgSQL
import Foundation
import NIOAdvanced
import PrivilegeModule

// MARK: - UserInfoController Concurrency (UserInfoController.swift)

extension PrivilegeSystem.UserInfoController {
    public func create(
        @OTOChainRelationBuilder<UUID, PUserInfo, PExtendedInfo>
        _ content: @Sendable @escaping () -> [OTORelation<UUID, OTORelation<PUserInfo, PExtendedInfo>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(content).get()
    }

    public func delete(
        infoIds: [UUID],
        allSatisfy: Bool = true
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(infoIds: infoIds, allSatisfy: allSatisfy).get()
    }

    public func update(
        with updater: PUserInfo.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUserInfo {
        try await update(with: updater).get()
    }

    public func create(
        relations: [OTORelation<UUID, OTORelation<PUserInfo, PExtendedInfo>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }
}
