import Fluent
import Foundation
import Policy
import ErrorHandle
import Collections
import PrivilegeModule
import Query
import LoggingAdvanced
import AnyCodable
import ResourceMacros

public struct PExtendedInfo: DTO.Model {
    public typealias QueriedModel = QExtendedInfo
    public let addresses: [PInfoSlice<Address>]
    public let alternateEmails: [PInfoSlice<AlternateEmail>]
    public let phones: [PInfoSlice<Phone>]
    
    public init(
        addresses: [PInfoSlice<Address>],
        alternateEmails: [PInfoSlice<AlternateEmail>],
        phones: [PInfoSlice<Phone>]
    ) {
        self.addresses = addresses
        self.alternateEmails = alternateEmails
        self.phones = phones
    }
    
    public var maps: [CodingKeys: AnyCodable] {[
        .addresses: .init(self.addresses.map { $0.json }),
        .alternateEmails: .init(self.alternateEmails.map { $0.json }),
        .phones: .init(self.phones.map { $0.json })
    ]}
}

public struct QExtendedInfo: DTO.Model {
    public typealias PrepareModel = PExtendedInfo
    public let addresses: [QInfoSlice<Address>]
    public let alternateEmails: [QInfoSlice<AlternateEmail>]
    public let phones: [QInfoSlice<Phone>]
    
    init(
        addresses: [QInfoSlice<Address>],
        alternateEmails: [QInfoSlice<AlternateEmail>],
        phones: [QInfoSlice<Phone>]
    ) {
        self.addresses = addresses
        self.alternateEmails = alternateEmails
        self.phones = phones
    }
    
    public var maps: [CodingKeys: AnyCodable] {[
        .addresses: .init(self.addresses.map { $0.json }),
        .alternateEmails: .init(self.alternateEmails.map { $0.json }),
        .phones: .init(self.phones.map { $0.json })
    ]}
}

extension PExtendedInfo: Codable {
    public enum CodingKeys: String, DTO.CodingKey {
        case addresses
        case alternateEmails = "alternate_emails"
        case phones
    }
}

extension QExtendedInfo: Codable {
    public enum CodingKeys: String, DTO.CodingKey {
        case addresses
        case alternateEmails = "alternate_emails"
        case phones
    }
}

public extension PExtendedInfo {
    func like(_ rhs: QueriedModel) -> Bool {
        for (k, v) in maps {
            guard
                let key = QueriedModel.CodingKeys(stringValue: k.stringValue),
                rhs.maps[key] == v
            else { return false }
        }
        return true
    }
}

public extension QExtendedInfo {
    func like(_ rhs: PrepareModel) -> Bool {
        // 以 PrepareModel 为基准来做比较，而非 Self
        for (k, v) in rhs.maps {
            guard
                let key = CodingKeys(stringValue: k.stringValue),
                maps[key] == v
            else { return false }
        }
        return true
    }
}

public extension Collection where Element == PExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.QueriedModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.PrepareModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}
