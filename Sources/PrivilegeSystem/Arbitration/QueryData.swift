import PrivilegeModule
@preconcurrency import AnyCodable

extension PrivilegeSystem.Arbitrator {
    struct QueryData: Encodable, Sendable {
        @Unknownable var user: DTO.User<DTO.Queried>
        @Unknownable var userInfo: DTO.UserInfo<DTO.Queried>
        @Unknownable var userInfoAddresses: DTO.UserExtendedInfo<DTO.Address, DTO.Queried>
        @Unknownable var userInfoAlternateEmails: DTO.UserExtendedInfo<DTO.AlternateEmail, DTO.Queried>
        @Unknownable var userInfoPhones: DTO.UserExtendedInfo<DTO.Phone, DTO.Queried>
        @Unknownable var group: DTO.Group<DTO.Queried>?
        
        @Unknownable var role: DTO.Role<DTO.Queried>
        @Unknownable var domain: DTO.Role<DTO.Queried>?
        
        var action: AnyAction
        var resource: AnyCodable
        
        enum CodingKeys: String, CodingKey {
            case resource = "resource"
            case action = "action"
            case user = "user"
            case userInfo = "user_info"
            case userInfoAddresses = "user_info_addresses"
            case userInfoAlternateEmails = "user_info_alternateEmails"
            case userInfoPhones = "user_info_phones"
            case role = "role"
            case group = "group"
            case domain = "domain"
        }
    }
}
