import Fluent
import Policy
import PgSQL
import NIOAdvanced
import OPA
import PrivilegeModule

// MARK: - PolicyController Concurrency (PolicyController.swift)

extension PrivilegeSystem.PolicyController {
    // MARK: Create (result-builder variants)

    public func create<T: PolicyType>(
        to model: T.Type,
        @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(to: model, content).get()
    }

    public func createWithReturning<T: PolicyType>(
        to model: T.Type,
        @MTORelationBuilder<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]] {
        try await createWithReturning(to: model, content).get()
    }

    // MARK: Create (array variants)

    public func create<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(to: model, relations: relations).get()
    }

    public func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: [MTORelation<DTO.Policy<T, DTO.Prepare>, T.Model.IDValue>]
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [DTO.Policy<T, DTO.Queried>]] {
        try await createWithReturning(to: model, relations: relations).get()
    }

    // MARK: Delete

    public func delete<T: PolicyType>(
        from model: T.Type = T.self,
        policy: OTORelation<DTO.Policy<T, DTO.Queried>, T.Model.IDValue>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(from: model, policy: policy).get()
    }
}
