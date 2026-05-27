import Fluent
import PgSQL
import NIOAdvanced
import PrivilegeModule

// MARK: - UserInfoController Concurrency (UserInfoController.swift)

extension PrivilegeSystem.UserInfoController {
    public func create(
        @OTOChainRelationBuilder<UUID, DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>
        _ content: @Sendable @escaping () -> [OTORelation<UUID, OTORelation<DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>>]
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
        with updater: DTO.UserInfo<DTO.Prepare>.Updater
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.UserInfo<DTO.Queried> {
        try await update(with: updater).get()
    }

    public func create(
        relations: [OTORelation<UUID, OTORelation<DTO.UserInfo<DTO.Prepare>, DTO.ExtendedInfo<DTO.Prepare>>>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(relations: relations).get()
    }
}
