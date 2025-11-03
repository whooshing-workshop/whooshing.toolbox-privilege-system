import PgSQL

protocol TdeMIG: PGMigration {
    var tdeEncrypt: Bool { set get }
    
    init(tdeEncrypt: Bool)
}

@usableFromInline
struct DefaultMIG<G: PGModel>: TdeMIG, Sendable {
    @usableFromInline
    typealias DataModel = G
    
    @usableFromInline
    var tdeEncrypt: Bool
    
    @inlinable
    init(tdeEncrypt: Bool = true) {
        self.tdeEncrypt = tdeEncrypt
    }
}
