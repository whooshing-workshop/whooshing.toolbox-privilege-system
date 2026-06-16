import Fluent
import Policy
import PgSQL
import Foundation
import NIOAdvanced
import OPA
import PrivilegeModule
import OrderedCollections

// MARK: - PolicyController Concurrency (PolicyController.swift)

extension PrivilegeSystem.PolicyController {
    // MARK: Create (result-builder variants)

    public func create<T: PolicyType>(
        to model: T.Type,
        @MTORelationBuilder<PPolicy<T>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(to: model, content).get()
    }

    public func createWithReturning<T: PolicyType>(
        to model: T.Type,
        @MTORelationBuilder<PPolicy<T>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [QPolicy<T>]] {
        try await createWithReturning(to: model, content).get()
    }

    // MARK: Create (array variants)

    public func create<T: PolicyType>(
        to model: T.Type,
        relations: OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(to: model, relations: relations).get()
    }

    public func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [QPolicy<T>]] {
        try await createWithReturning(to: model, relations: relations).get()
    }

    // MARK: Delete

    public func delete<T: PolicyType>(
        from model: T.Type = T.self,
        policy: OTORelation<QPolicy<T>, T.Model.IDValue>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(from: model, policy: policy).get()
    }
}
