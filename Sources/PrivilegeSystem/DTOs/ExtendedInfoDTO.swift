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

public extension DTO.ExtendedInfo where T == DTO.Prepare {
    func like(_ rhs: QExtendedInfo) -> Bool {
        self.addresses.like(rhs.addresses) &&
        self.alternateEmails.like(rhs.alternateEmails) &&
        self.phones.like(rhs.phones)
    }
}

public extension DTO.ExtendedInfo where T == DTO.Queried {
    func like(_ rhs: PExtendedInfo) -> Bool {
        self.addresses.like(rhs.addresses) &&
        self.alternateEmails.like(rhs.alternateEmails) &&
        self.phones.like(rhs.phones)
    }
}

public extension Collection where Element == PExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == QExtendedInfo {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == PExtendedInfo {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
