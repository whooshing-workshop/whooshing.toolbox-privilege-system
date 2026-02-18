import Policy

extension Role: PolicyType {
    package typealias Model = Role
    package static let namePrefix = "role"
    package static let typeId = "role"
    package static let regoHead = """
    input.user.id == input.user_info.userId
    input.user_info.id == input.user_info_addresses.userInfoId
    input.user_info.id == input.user_info_alternateEmails.userInfoId
    input.user_info.id == input.user_info_phones.userInfoId
    input.group.id == 
    """
}

typealias RolePolicy = PolicyExp<Role>
