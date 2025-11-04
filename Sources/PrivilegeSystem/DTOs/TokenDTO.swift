import Vapor

public struct TokenDTO: Sendable {
    public let credential: String
    public let token: String

    init(from token: Token) {
        self.credential = token.credential
        self.token = token.token
    }
}
