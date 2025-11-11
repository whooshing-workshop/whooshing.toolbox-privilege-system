import ACL

extension Privilege: ACLType {
    public static var namePrefix: String { "privilege" }
}

public extension Privilege {
    typealias ACL = ACLExp<Privilege>
}
