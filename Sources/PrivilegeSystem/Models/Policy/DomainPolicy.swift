import Policy

extension Domain: PolicyType {
    package typealias Model = Domain
    package static var namePrefix: String { "domain" }
    package static var typeId: String { "domain" }
}

typealias DomainPolicy = PolicyExp<Domain>
