import Foundation
import PrivilegeModule

// MARK: - AccountController Concurrency (AccountController.swift)

extension PrivilegeSystem.AccountController {
    public func register(
        for user: PUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await register(for: user, on: transactor).get()
    }

    public func login(
        by userData: PUser,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QToken {
        try await login(by: userData, on: transactor).get()
    }

    public func authenticate(
        token: EncryptedToken,
        roleId: UUID,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> AuthData {
        try await authenticate(token: token, roleId: roleId, on: transactor).get()
    }

    @discardableResult
    public func changePassword(
        for userData: PUser,
        to hashedPassword: Data,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await changePassword(for: userData, to: hashedPassword, on: transactor).get()
    }

    @discardableResult
    public func changePassword(
        for userData: PUser,
        to hashedPassword: String,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await changePassword(for: userData, to: hashedPassword, on: transactor).get()
    }
    
    @discardableResult
    public func changePassword(
        for userData: QUser,
        to hashedPassword: String,
        on transactor: Transactor? = nil
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> QUser {
        try await changePassword(for: userData, to: hashedPassword, on: transactor).get()
    }
}
