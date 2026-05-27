import Fluent
import NIOAdvanced
import Foundation

// MARK: - Query.Builder Concurrency (All.swift)

public extension Query.Builder {
    // MARK: all() — 全量结果

    func all() async throws(Query.Errcase.ErrType) -> [Model] {
        try await all().get()
    }

    // MARK: all(_:) — 单字段

    func all<Value>(
        _ field: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> [Value] where Value: Codable & Sendable {
        try await all(field).get()
    }

    func all<Value>(
        _ field: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> [Value?] where Value: Codable & Sendable {
        try await all(field).get()
    }

    func all<Value>(
        _ field: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> [Value] where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await all(field).get()
    }

    func all<Value>(
        _ field: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> [Value?] where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await all(field).get()
    }

    func all(
        _ field: KeyPath<Model, Date>
    ) async throws(Query.Errcase.ErrType) -> [Date] {
        try await all(field).get()
    }

    // MARK: all(_:_:) — joined 字段

    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) async throws(Query.Errcase.ErrType) -> [Value] where Joined: Query.Queriable, Value: Codable & Sendable {
        try await all(joined, field).get()
    }

    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) async throws(Query.Errcase.ErrType) -> [Value?] where Joined: Query.Queriable, Value: Codable & Sendable {
        try await all(joined, field).get()
    }

    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value>
    ) async throws(Query.Errcase.ErrType) -> [Value] where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await all(joined, field).get()
    }

    func all<Joined, Value>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Value?>
    ) async throws(Query.Errcase.ErrType) -> [Value?] where Joined: Query.Queriable, Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await all(joined, field).get()
    }

    func all<Joined>(
        _ joined: Joined.Type,
        _ field: KeyPath<Joined, Date>
    ) async throws(Query.Errcase.ErrType) -> [Date] where Joined: Query.Queriable {
        try await all(joined, field).get()
    }
}
