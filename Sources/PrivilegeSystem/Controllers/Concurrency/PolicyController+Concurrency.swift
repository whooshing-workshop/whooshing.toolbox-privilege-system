import PrivilegeModule

// MARK: - PolicyController Concurrency (PolicyController.swift)

extension PrivilegeSystem.PolicyController {
    // MARK: Create (result-builder variants)

    public func create<T: PolicyType>(
        on transactor: Transactor? = nil,
        to model: T.Type,
        @MTORelationBuilder<PPolicy<T>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(on: transactor, to: model, content).get()
    }

    public func createWithReturning<T: PolicyType>(
        on transactor: Transactor? = nil,
        to model: T.Type,
        @MTORelationBuilder<PPolicy<T>, T.Model.IDValue>
        _ content: @Sendable @escaping () -> OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [QPolicy<T>]] {
        try await createWithReturning(on: transactor, to: model, content).get()
    }

    // MARK: Create (array variants)

    public func create<T: PolicyType>(
        to model: T.Type,
        relations: OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await create(to: model, relations: relations, on: transactor).get()
    }

    public func createWithReturning<T: PolicyType>(
        to model: T.Type,
        relations: OrderedSet<MTORelation<PPolicy<T>, T.Model.IDValue>>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> [T.Model.IDValue: [QPolicy<T>]] {
        try await createWithReturning(to: model, relations: relations, on: transactor).get()
    }

    // MARK: Delete

    public func delete<T: PolicyType>(
        from model: T.Type = T.self,
        policy: OTORelation<QPolicy<T>, T.Model.IDValue>,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) {
        try await delete(from: model, policy: policy, on: transactor).get()
    }
}
