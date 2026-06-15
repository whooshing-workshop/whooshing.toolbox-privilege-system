import Foundation
import Cryptos
import Fluent
import PgSQL
import NIOAdvanced
import PrivilegeModule

// MARK: - AccountController Concurrency (AccountController.swift)

extension PrivilegeSystem.AccountController {
    public func register(
        for user: PUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await register(for: user).get()
    }

    public func login(
        by userData: PUser
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QToken {
        try await login(by: userData).get()
    }

    public func authenticate(
        token: Token
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> SendableSymmKey {
        try await authenticate(token: token).get()
    }

    public func changePassword(
        for userData: PUser,
        to hashedPassword: Data
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await changePassword(for: userData, to: hashedPassword).get()
    }

    public func changePassword(
        for userData: PUser,
        to hashedPassword: String
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await changePassword(for: userData, to: hashedPassword).get()
    }
}
