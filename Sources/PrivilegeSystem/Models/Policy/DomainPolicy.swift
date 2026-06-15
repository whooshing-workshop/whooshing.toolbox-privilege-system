import Policy

public enum Domain: PolicyType {
    public typealias Model = __SDBM.Domain
    public static var namePrefix: String { "domain" }
    public static var typeId: String { "domain" }
}

typealias DomainType = Domain

extension __SDBM {
    typealias DomainPolicy = PolicyExp<DomainType>
}
