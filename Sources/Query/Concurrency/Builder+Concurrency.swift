import NIOAdvanced
import Fluent

// MARK: - Query.Builder Concurrency (Builder.swift)

public extension Query.Builder {
    func first() async throws(Query.Errcase.ErrType) -> Model? {
        try await first().get()
    }

    func page(with index: Int, size: Int) async throws(Query.Errcase.ErrType) -> Page<Model> {
        try await page(with: index, size: size).get()
    }

    func paginate(_ request: PageRequest) async throws(Query.Errcase.ErrType) -> Page<Model> {
        try await paginate(request).get()
    }
}
