import Foundation
import Cryptos
import Fluent
import PgSQL
import NIOAdvanced
import PrivilegeModule

// MARK: - AccountController Concurrency (AccountController.swift)

extension PrivilegeSystem.AccountController {
    public func register(
        for user: DTO.User<DTO.Prepare>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.User<DTO.Queried> {
        try await register(for: user).get()
    }

    public func login(
        by userData: DTO.User<DTO.Prepare>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.Token<DTO.Queried> {
        try await login(by: userData).get()
    }

    public func authenticate(
        token: DTO.Token<DTO.Prepare>
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> Crypto.Symm.Key {
        try await authenticate(token: token).get()
    }

    public func changePassword(
        for userData: DTO.User<DTO.Prepare>,
        to hashedPasswd: Data
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.User<DTO.Queried> {
        try await changePassword(for: userData, to: hashedPasswd).get()
    }

    public func changePassword(
        for userData: DTO.User<DTO.Prepare>,
        to hashedPasswd: String
    ) async throws(PrivilegeSystem.Errcase.ErrType) -> DTO.User<DTO.Queried> {
        try await changePassword(for: userData, to: hashedPasswd).get()
    }
}
