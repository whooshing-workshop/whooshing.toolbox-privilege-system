import ACL

extension Domain: ACLType {
    static var namePrefix: String { "domain" }
}

extension Domain {
    typealias ACL = ACLExp<Domain>
}
