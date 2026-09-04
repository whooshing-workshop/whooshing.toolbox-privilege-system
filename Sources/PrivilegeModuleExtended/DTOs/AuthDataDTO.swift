import Vapor
import Cryptos
import LoggingAdvanced

public struct AuthData: Content, Authenticatable, CustomStringConvertible, Loggerable {
    public let key: SendableSymmKey
    public let token: QToken
    public let role: QRole
    
    public init(key: SendableSymmKey, token: QToken, role: QRole) {
        self.key = key
        self.token = token
        self.role = role
    }
    
    public var json: [String: AnyCodable] {[
        "key": AnyCodable(key),
        "token": AnyCodable(token),
        "role": AnyCodable(role)
    ]}
    
    public var summaryJson: [String: AnyCodable] {[
        "key": AnyCodable(key),
        "token": AnyCodable(token),
        "role": AnyCodable([
            "id": AnyCodable(role.id.shortString),
            "name": AnyCodable(role.name)
        ])
    ]}
    
    public var description: String {
        formatJson(json)
    }
    
    public var summaryDescription: String {
        formatJson(summaryJson)
    }
}
