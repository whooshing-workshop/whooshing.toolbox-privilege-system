import Foundation
import PrivilegeModule

public struct PExtendedInfo: DTO.Model {
    public let addresses: OrderedSet<PInfoSlice<Address>>
    public let alternateEmails: OrderedSet<PInfoSlice<AlternateEmail>>
    public let phones: OrderedSet<PInfoSlice<Phone>>
    
    public static let logName: String = "PExtendedInfo"
    
    public init(
        addresses: OrderedSet<PInfoSlice<Address>> = [],
        alternateEmails: OrderedSet<PInfoSlice<AlternateEmail>> = [],
        phones: OrderedSet<PInfoSlice<Phone>> = []
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

extension PExtendedInfo: Codable {
    public enum CodingKeys: String, DTO.CodingKey {
        case addresses
        case alternateEmails = "alternate_emails"
        case phones
    }
}
