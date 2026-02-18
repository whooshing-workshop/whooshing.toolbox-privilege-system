import Policy

extension Domain: PolicyType {
    package typealias Model = Domain
    package static let namePrefix = "domain"
    package static let typeId = "domain"
    package static let regoHead = "asdf"
}

typealias DomainPolicy = PolicyExp<Domain>
