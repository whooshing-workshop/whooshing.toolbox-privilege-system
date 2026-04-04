import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable

public typealias PExtendedInfo = DTO.ExtendedInfo<DTO.Prepare>
public typealias QExtendedInfo = DTO.ExtendedInfo<DTO.Queried>

public extension DTO {
    struct ExtendedInfo<T: DTO.Status>: Sendable, Hashable {
        public let addresses: [DTO.InfoSlice<DTO.Address, T>]
        public let alternateEmails: [DTO.InfoSlice<DTO.AlternateEmail, T>]
        public let phones: [DTO.InfoSlice<DTO.Phone, T>]
        
        init(
            _addresses: [DTO.InfoSlice<DTO.Address, T>],
            _alternateEmails: [DTO.InfoSlice<DTO.AlternateEmail, T>],
            _phones: [DTO.InfoSlice<DTO.Phone, T>]
        ) {
            self.addresses = _addresses
            self.alternateEmails = _alternateEmails
            self.phones = _phones
        }
    }
}

public extension DTO.ExtendedInfo where T == DTO.Prepare {
    init(
        addresses: [DTO.InfoSlice<DTO.Address, T>] = [],
        alternateEmails: [DTO.InfoSlice<DTO.AlternateEmail, T>] = [],
        phones: [DTO.InfoSlice<DTO.Phone, T>] = []
    ) {
        self = Self.init(
            _addresses: addresses,
            _alternateEmails: alternateEmails,
            _phones: phones
        )
    }
}

extension DTO.ExtendedInfo where T == DTO.Queried {
    init(
        addresses: [DTO.InfoSlice<DTO.Address, T>] = [],
        alternateEmails: [DTO.InfoSlice<DTO.AlternateEmail, T>] = [],
        phones: [DTO.InfoSlice<DTO.Phone, T>] = []
    ) {
        self = Self.init(
            _addresses: addresses,
            _alternateEmails: alternateEmails,
            _phones: phones
        )
    }
}

extension DTO.ExtendedInfo: Encodable where T == DTO.Queried {}

extension DTO.ExtendedInfo: CustomStringConvertible, Loggerable {
    public var logDescription: String {
        let statusLabel = "\(T.self)".components(separatedBy: ".").last ?? "\(T.self)"
        let data: [String: AnyCodable] = [
            "addresses": AnyCodable(self.addresses.map { $0.value }),
            "alternate_emails": AnyCodable(self.alternateEmails.map { $0.value }),
            "phones": AnyCodable(self.phones.map { $0.value })
        ]
        return formatQuery([
            "status": AnyCodable(statusLabel),
            "data": AnyCodable(data)
        ])
    }
    
    public var description: String {
        logDescription
    }
}

public func == (lhs: PExtendedInfo, rhs: QExtendedInfo) -> Bool {
    lhs.addresses.elementsEqual(rhs.addresses, by: ==) &&
    lhs.alternateEmails.elementsEqual(rhs.alternateEmails, by: ==) &&
    lhs.phones.elementsEqual(rhs.phones, by: ==)
}

public func == (lhs: QExtendedInfo, rhs: PExtendedInfo) -> Bool {
    lhs.addresses.elementsEqual(rhs.addresses, by: ==) &&
    lhs.alternateEmails.elementsEqual(rhs.alternateEmails, by: ==) &&
    lhs.phones.elementsEqual(rhs.phones, by: ==)
}

public func == (lhs: [PExtendedInfo], rhs: [QExtendedInfo]) -> Bool {
    lhs.elementsEqual(rhs, by: ==)
}

public func == (lhs: [QExtendedInfo], rhs: [PExtendedInfo]) -> Bool {
    lhs.elementsEqual(rhs, by: ==)
}
