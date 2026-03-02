import Policy

extension Domain: PolicyType {
    public typealias Model = Domain
    public static var namePrefix: String { "domain" }
    public static var typeId: String { "domain" }
}

typealias DomainPolicy = PolicyExp<Domain>
