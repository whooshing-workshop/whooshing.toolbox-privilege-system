import PgSQL

public protocol TdeMIG: PGMigration {
    var tdeEncrypt: Bool { set get }
    
    init(tdeEncrypt: Bool)
}

public struct DefaultMIG<G: PGModel>: TdeMIG, Sendable {
    
    public typealias DataModel = G
    
    public var tdeEncrypt: Bool
    
    public init(tdeEncrypt: Bool = true) {
        self.tdeEncrypt = tdeEncrypt
    }
}
