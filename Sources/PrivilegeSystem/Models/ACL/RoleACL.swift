import ACL

extension Role: ACLType {
    static var namePrefix: String { "role" }
}

extension Role {
    typealias ACL = ACLExp<Role>
}
