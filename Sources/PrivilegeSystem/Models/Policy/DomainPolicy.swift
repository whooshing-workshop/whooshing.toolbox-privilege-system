import Policy

extension Domain: PolicyType {
    typealias Model = Domain
    static var namePrefix: String { "domain" }
}

typealias DomainPolicy = PolicyExp<Domain>
