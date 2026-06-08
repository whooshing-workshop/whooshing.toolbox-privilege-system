import re

def update_file(path, old_block, new_block):
    with open(path, 'r') as f:
        text = f.read()
    
    # We will use string replace or regex
    # The simplest is to find 'extension ... Encodable where T == DTO.Queried {'
    # and replace the block up to '}'
    
    pattern = re.compile(old_block, re.MULTILINE | re.DOTALL)
    new_text = pattern.sub(new_block, text)
    
    with open(path, 'w') as f:
        f.write(new_text)

# UserInfoDTO
update_file(
    "/Users/clwang/GitHub/whooshing.toolbox-privilege-system/Sources/PrivilegeSystem/DTOs/UserInfoDTO.swift",
    r"extension DTO\.UserInfo: Encodable where T == DTO\.Queried \{.*?\n\}",
    """extension DTO.UserInfo: Encodable {
    enum CodingKeys: String, CodingKey {
        case userId
        case nickname
        case identifier
        case birthday
        case other
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nickname, forKey: .nickname)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(other, forKey: .other)
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(userId, forKey: .userId)
            try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
            try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
        }
    }
}"""
)

# InfoSliceDTO
update_file(
    "/Users/clwang/GitHub/whooshing.toolbox-privilege-system/Sources/PrivilegeSystem/DTOs/InfoSliceDTO.swift",
    r"extension DTO\.InfoSlice: Encodable where T == DTO\.Queried \{.*?\n\}",
    """extension DTO.InfoSlice: Encodable {
    enum CodingKeys: String, CodingKey {
        case value
        case order
        case description
        case id
        case userInfoId = "user_info_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(order, forKey: .order)
        try container.encode(description, forKey: .description)
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(userInfoId, forKey: .userInfoId)
            try container.encode(DateResponse(self.createdAt), forKey: .createdAt)
            try container.encode(DateResponse(self.updatedAt), forKey: .updatedAt)
        }
    }
}"""
)

# ResourceDTO
update_file(
    "/Users/clwang/GitHub/whooshing.toolbox-privilege-system/Sources/PrivilegeModule/DTOs/ResourceDTO.swift",
    r"extension PM\.ResourceDTO: Encodable where T == DTO\.Queried \{.*?\n\}",
    """extension PM.ResourceDTO: Encodable {
    enum CodingKeys: CodingKey {
        case data
        case id
        case createdAt
        case updatedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        if T.self != DTO.Prepare.self {
            try container.encode(id, forKey: .id)
            try container.encode(self.createdAt, forKey: .createdAt)
            try container.encode(self.updatedAt, forKey: .updatedAt)
        }
    }
}"""
)

# ExtendedInfoDTO
update_file(
    "/Users/clwang/GitHub/whooshing.toolbox-privilege-system/Sources/PrivilegeSystem/DTOs/ExtendedInfoDTO.swift",
    r"extension DTO\.ExtendedInfo: Encodable where T == DTO\.Queried \{\}",
    "extension DTO.ExtendedInfo: Encodable {}"
)

print("Done")
