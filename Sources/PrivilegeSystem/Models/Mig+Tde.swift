import PgSQL

protocol TdeMIG: PGMigration {
    var tdeEncrypt: Bool { set get }
    
    init(tdeEncrypt: Bool)
}
