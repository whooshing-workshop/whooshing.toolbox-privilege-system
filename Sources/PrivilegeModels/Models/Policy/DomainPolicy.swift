import DTOBuilder

public enum Domain: PolicyType {
    public typealias DTOModel = QDomain
    public typealias Model = __SDBM.Domain
    public static var namePrefix: String { "domain" }
    public static var typeId: String { "domain" }
}

package typealias DomainType = Domain

package extension __SDBM {
    typealias DomainPolicy = PolicyExp<DomainType>
}
