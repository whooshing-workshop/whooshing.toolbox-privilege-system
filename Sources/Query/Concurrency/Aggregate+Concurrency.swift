import Fluent
import NIOAdvanced
import Foundation

// MARK: - Query.Builder Concurrency (Aggregate.swift)

public extension Query.Builder {
    // MARK: count

    func count() async throws(Query.Errcase.ErrType) -> Int {
        try await count().get()
    }

    func count<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Int where Value: Codable & Sendable {
        try await count(key).get()
    }

    func count<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Int where Value: Codable & Sendable {
        try await count(key).get()
    }

    func count<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Int where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await count(key).get()
    }

    func count<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Int where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await count(key).get()
    }

    func count(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Int {
        try await count(key).get()
    }

    // MARK: sum (non-optional result)

    func sum<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (sum(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func sum<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (sum(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func sum<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (sum(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func sum<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (sum(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func sum(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date {
        try await (sum(key) as EventLoopRes<Date, Query.Errcase>).get()
    }

    // MARK: sum (optional result)

    func sumOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (sum(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func sumOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (sum(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func sumOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (sum(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func sumOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (sum(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func sumOptional(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date? {
        try await (sum(key) as EventLoopRes<Date?, Query.Errcase>).get()
    }

    // MARK: average (non-optional result)

    func average<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (average(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func average<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (average(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func average<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (average(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func average<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (average(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func average(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date {
        try await (average(key) as EventLoopRes<Date, Query.Errcase>).get()
    }

    // MARK: average (optional result)

    func averageOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (average(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func averageOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (average(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func averageOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (average(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func averageOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (average(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func averageOptional(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date? {
        try await (average(key) as EventLoopRes<Date?, Query.Errcase>).get()
    }

    // MARK: min (non-optional result)

    func min<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (min(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func min<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (min(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func min<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (min(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func min<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (min(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func min(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date {
        try await (min(key) as EventLoopRes<Date, Query.Errcase>).get()
    }

    // MARK: min (optional result)

    func minOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (min(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func minOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (min(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func minOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (min(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func minOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (min(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func minOptional(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date? {
        try await (min(key) as EventLoopRes<Date?, Query.Errcase>).get()
    }

    // MARK: max (non-optional result)

    func max<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (max(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func max<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable {
        try await (max(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func max<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (max(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func max<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (max(key) as EventLoopRes<Value, Query.Errcase>).get()
    }

    func max(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date {
        try await (max(key) as EventLoopRes<Date, Query.Errcase>).get()
    }

    // MARK: max (optional result)

    func maxOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (max(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func maxOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable {
        try await (max(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func maxOptional<Value>(
        _ key: KeyPath<Model, Value>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (max(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func maxOptional<Value>(
        _ key: KeyPath<Model, Value?>
    ) async throws(Query.Errcase.ErrType) -> Value? where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String {
        try await (max(key) as EventLoopRes<Value?, Query.Errcase>).get()
    }

    func maxOptional(_ key: KeyPath<Model, Date>) async throws(Query.Errcase.ErrType) -> Date? {
        try await (max(key) as EventLoopRes<Date?, Query.Errcase>).get()
    }

    // MARK: aggregate (generic)

    func aggregate<Result>(
        _ aggregate: DatabaseQuery.Aggregate,
        as: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Result: Codable & Sendable {
        try await self.aggregate(aggregate, as: `as`).get()
    }

    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Value: Codable & Sendable, Result: Codable & Sendable {
        try await self.aggregate(method, field, as: result).get()
    }

    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Value: Codable & Sendable, Result: Codable & Sendable {
        try await self.aggregate(method, field, as: result).get()
    }

    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value>,
        as result: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        try await self.aggregate(method, field, as: result).get()
    }

    func aggregate<Value, Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Value?>,
        as result: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Value: Codable & Sendable & RawRepresentable, Value.RawValue == String, Result: Codable & Sendable {
        try await self.aggregate(method, field, as: result).get()
    }

    func aggregate<Result>(
        _ method: DatabaseQuery.Aggregate.Method,
        _ field: KeyPath<Model, Date>,
        as result: Result.Type = Result.self
    ) async throws(Query.Errcase.ErrType) -> Result where Result: Codable & Sendable {
        try await self.aggregate(method, field, as: result).get()
    }
}
