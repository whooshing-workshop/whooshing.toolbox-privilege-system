import Vapor
import Cryptos

public struct AuthData: Content, Authenticatable {
    public let key: SendableSymmKey
    public let token: QToken
    public let role: QRole
    
    public init(key: SendableSymmKey, token: QToken, role: QRole) {
        self.key = key
        self.token = token
        self.role = role
    }
}
