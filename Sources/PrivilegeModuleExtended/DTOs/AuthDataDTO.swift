import Vapor
import Cryptos

public struct AuthData: Content, Authenticatable {
    public let key: SendableSymmKey
    public let token: QToken
    
    public init(key: SendableSymmKey, token: QToken) {
        self.key = key
        self.token = token
    }
}
