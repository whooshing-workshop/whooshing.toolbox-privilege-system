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
    
    public static let logName: String = "PExtendedInfo"
    
    public init(
        addresses: [PInfoSlice<Address>] = [],
        alternateEmails: [PInfoSlice<AlternateEmail>] = [],
        phones: [PInfoSlice<Phone>] = []
    ) {
        self.addresses = addresses
        self.alternateEmails = alternateEmails
        self.phones = phones
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .addresses: self.addresses.map { $0.json },
        .alternateEmails: self.alternateEmails.map { $0.json },
        .phones: self.phones.map { $0.json }
    ]}
    
    public var summaryKeys: [CodingKeys] { [.addresses, .alternateEmails, .phones] }
}

public struct QExtendedInfo: DTO.Model {
    public typealias PrepareModel = PExtendedInfo
    public let addresses: [QInfoSlice<Address>]
    public let alternateEmails: [QInfoSlice<AlternateEmail>]
    public let phones: [QInfoSlice<Phone>]
    
    public static let logName: String = "QExtendedInfo"
    
    init(
        addresses: [QInfoSlice<Address>] = [],
        alternateEmails: [QInfoSlice<AlternateEmail>] = [],
        phones: [QInfoSlice<Phone>] = []
    ) {
        self.addresses = addresses
        self.alternateEmails = alternateEmails
        self.phones = phones
    }
    
    public var maps: [CodingKeys: AnyHashable?] {[
        .addresses: .init(self.addresses.map { $0.json }),
        .alternateEmails: .init(self.alternateEmails.map { $0.json }),
        .phones: .init(self.phones.map { $0.json })
    ]}
    
    public var summaryKeys: [CodingKeys] { [.addresses, .alternateEmails, .phones] }
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
        addresses.like(rhs.addresses) &&
        alternateEmails.like(rhs.alternateEmails) &&
        phones.like(rhs.phones)
    }
}

public extension QExtendedInfo {
    func like(_ rhs: PrepareModel) -> Bool {
        rhs.addresses.like(self.addresses) &&
        rhs.alternateEmails.like(self.alternateEmails) &&
        rhs.phones.like(self.phones)
    }
}

public extension Collection where Element == PExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.QueriedModel {
        self.elementsEqual(rhs, by: { $0.like($1) })
    }
}

public extension Collection where Element == QExtendedInfo {
    func like<C>(_ rhs: C) -> Bool where C: Collection, C.Element == Element.PrepareModel {
        self.elementsEqual(rhs, by: { $1.like($0) })
    }
}
