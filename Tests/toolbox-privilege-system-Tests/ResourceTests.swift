import Testing
import Foundation
import Fluent
@preconcurrency import AnyCodable
@testable import PrivilegeSystem
@testable import PrivilegeModule

enum FileOperation: String, OperationList {
    case read
    case write
    case execute
}

typealias PFileResource = PModule.PResource<FileResource>
typealias QFileResource = PModule.QResource<FileResource>

struct FileResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = FileOperation

    static let type: ResourceList = .file
    var name: String
    var path: String
    var isPrivate: Bool

    var json: [String: AnyCodable] {
        return [
            "name": AnyCodable(name),
            "path": AnyCodable(path),
            "isPrivate": AnyCodable(isPrivate)
        ]
    }

    static var mirrors: [PartialKeyPath<FileResource>: [String]] {
        return [
            \.name: ["name"],
            \.path: ["path"],
            \.isPrivate: ["isPrivate"]
        ]
    }
}

enum JsonOperation: String, OperationList {
    case anything
    case view
    case manage_all
    case edit
    case moderate
    case publish
    case deploy
    case read
    case write
    case any
    case any_operation
    case hr_task
}

struct JsonResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = JsonOperation

    static let type: ResourceList = .file
    var name: String
    var content: [String: AnyCodable]

    var json: [String: AnyCodable] {
        var base = content
        base["name"] = AnyCodable(name)
        return base
    }

    public static func == (lhs: JsonResource, rhs: JsonResource) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static var mirrors: [PartialKeyPath<JsonResource>: [String]] {
        return [
            \.name: ["name"]
        ]
    }
}

enum DirectoryOperation: String, OperationList {
    case list
    case createChild
    case deleteChild
}

typealias PDirectoryResource = PModule.PResource<DirectoryResource>
typealias QDirectoryResource = PModule.QResource<DirectoryResource>

struct DirectoryResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = DirectoryOperation

    static let type: ResourceList = .directory
    var name: String
    var path: String
    var ownerId: UUID

    var json: [String: AnyCodable] {
        return [
            "name": AnyCodable(name),
            "path": AnyCodable(path),
            "ownerId": AnyCodable(ownerId.uuidString)
        ]
    }

    static var mirrors: [PartialKeyPath<DirectoryResource>: [String]] {
        return [
            \.name: ["name"],
            \.path: ["path"],
            \.ownerId: ["ownerId"]
        ]
    }
}

enum AliasOperation: String, OperationList {
    case resolve
}

typealias PAliasResource = PModule.PResource<AliasResource>
typealias QAliasResource = PModule.QResource<AliasResource>

struct AliasResource: Resource, Hashable {
    typealias ResourceType = ResourceList
    typealias Operations = AliasOperation

    static let type: ResourceList = .alias
    var name: String
    var targetId: UUID

    var json: [String: AnyCodable] {
        return [
            "name": AnyCodable(name),
            "targetId": AnyCodable(targetId.uuidString)
        ]
    }

    static var mirrors: [PartialKeyPath<AliasResource>: [String]] {
        return [
            \.name: ["name"],
            \.targetId: ["targetId"]
        ]
    }
}

@Suite("资源及资源关系 测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct ResourceTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .resource {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("创建多种资源并验证")
    func resource_CreateAndQuery() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file1 = FileResource(name: "public_doc.txt", path: "/docs/public_doc.txt", isPrivate: false)
        let file2 = FileResource(name: "secret_keys.env", path: "/etc/secret_keys.env", isPrivate: true)
        let file3 = FileResource(name: "report.pdf", path: "/reports/report.pdf", isPrivate: false)
        
        let dir1 = DirectoryResource(name: "docs_folder", path: "/docs", ownerId: UUID())
        let dir2 = DirectoryResource(name: "etc_folder", path: "/etc", ownerId: UUID())
        
        let alias1 = AliasResource(name: "shortcut_to_report", targetId: UUID())
        
        let fileDtos = [
            PFileResource(data: file1),
            PFileResource(data: file2),
            PFileResource(data: file3)
        ]
        
        let dirDtos = [
            PDirectoryResource(data: dir1),
            PDirectoryResource(data: dir2)
        ]
        
        let aliasDtos = [
            PAliasResource(data: alias1)
        ]
        
        // 测试创建
        let createdFiles = try await m.resource.create(resources: fileDtos).get()
        let createdDirs = try await m.resource.create(resources: dirDtos).get()
        let createdAliases = try await m.resource.create(resources: aliasDtos).get()
        
        #expect(createdFiles.count == 3)
        #expect(createdDirs.count == 2)
        #expect(createdAliases.count == 1)
        
        #expect(createdFiles[0].data.name == "public_doc.txt")
        #expect(createdFiles[1].data.isPrivate == true)
        #expect(createdDirs[0].data.path == "/docs")
        
        var queriedFiles: Int = -1
        
        do {
            // 测试查询
            queriedFiles = try await PModule.ResourceModel<FileResource>.query(on: m.db)
                .filter(\.$id ~~ [createdFiles[0].id, createdFiles[1].id])
                .count()
        } catch {
            print(String(reflecting: error))
            #expect(Bool(false))
        }
        
        #expect(queriedFiles == 2)
    }
    
    @Test("修改资源信息")
    func resource_Update() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file = FileResource(name: "temp.txt", path: "/tmp/temp.txt", isPrivate: false)
        let created = try await m.resource.create(resources: [
            PFileResource(data: file)
        ]).get()
        let resourceId = created[0].id
        
        // 更新 isPrivate 为 true
        let updater = PFileResource.Updater(resourceId: resourceId)
            .update(data: { q in
                var d = q.data
                d.isPrivate = true
                return d
            })
        
        let updated: QFileResource = try await m.resource.update(with: updater).get()
        #expect(updated.data.isPrivate == true)
        #expect(updated.data.name == "temp.txt") // 其余信息不变
    }
    
    @Test("附加与移除资源权限 (MTMRelation)")
    func resource_Privilege_AttachDetach() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file = FileResource(name: "attach.txt", path: "/tmp/attach.txt", isPrivate: true)
        let resourceDTO = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<FileResource, DTO.Prepare>(data: file)
        ]).get().first!
        
        let suffix = UUID().uuidString
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "AttachTestPrivilege-\(suffix)",
                description: "附加测试专用",
                policy: "allow if { true }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        
        let anyResourceDTO = PModule.AnyResourceDTO.init(resourceDTO)
        
        // 测试 Attach
        try await m.privilege.attach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()

        // 验证 Attach
        let siblings = try await privilegeDTO.model.$resources.get(on: m.db)
        #expect(siblings.contains(where: { $0.id == anyResourceDTO.id }))
        
        // 测试 Detach
        try await m.privilege.detach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        
        let siblingsAfter = try await privilegeDTO.model.$resources.get(reload: true, on: m.db)
        
        #expect(!siblingsAfter.contains(where: { $0.id == anyResourceDTO.id }))
    }
    
    @Test("查询与验证资源权限")
    func resource_Privilege_QueryAndVerify() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file = FileResource(name: "query_verify.txt", path: "/tmp/query_verify.txt", isPrivate: true)
        let resourceDTO = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<FileResource, DTO.Prepare>(data: file)
        ]).get().first!
        
        let suffix = UUID().uuidString
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "QueryTestPrivilege-\(suffix)",
                description: "查询测试专用",
                policy: "allow if { true }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        
        let anyResourceDTO = PModule.AnyResourceDTO.init(resourceDTO)
        
        // 先 Attach
        try await m.privilege.attach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        
        // 1. 测试 privilege(attachedTo:) -> T: Resource
        let attachedPrivileges = try await m.privilege.privilege(attachedTo: resourceDTO).get()
        #expect(attachedPrivileges.contains(where: { $0.id == privilegeDTO.id }))
        
        // 2. 测试 privilege(attachedTo:) -> AnyResourceDTO
        let attachedPrivilegesAny = try await m.privilege.privilege(attachedTo: anyResourceDTO).get()
        #expect(attachedPrivilegesAny.contains(where: { $0.id == privilegeDTO.id }))
        
        // 3. 测试 is(privilege:attachedTo:) -> T: Resource
        let isAttached = try await m.privilege.is(privilege: privilegeDTO, attachedTo: resourceDTO).get()
        #expect(isAttached == true)
        
        // 4. 测试 is(privilege:attachedTo:) -> AnyResourceDTO
        let isAttachedAny = try await m.privilege.is(privilege: privilegeDTO, attachedTo: anyResourceDTO).get()
        #expect(isAttachedAny == true)
        
        // 5. 测试未绑定的权限
        let otherPrivileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "OtherPrivilege-\(suffix)",
                policy: "allow if { true }"
            )
        ]).get()
        let otherPrivilegeDTO = otherPrivileges[0]
        
        let isOtherAttached = try await m.privilege.is(privilege: otherPrivilegeDTO, attachedTo: resourceDTO).get()
        #expect(isOtherAttached == false)
        
        // 清理
        try await m.privilege.detach {
            [privilegeDTO] => [anyResourceDTO]
        }.get()
        try await m.privilege.delete(policy: privilegeDTO).get()
        try await m.privilege.delete(policy: otherPrivilegeDTO).get()
        try await m.resource.delete(ids: [resourceDTO.id]).get()
    }
    
    @Test("修改资源权限信息")
    func privilege_Update() async throws {
        let (_, m) = try await TestingShared.getSystem()
        
        let privileges = try await m.privilege.createWithReturning(privileges: [
            .init(
                name: "UpdateTestPrivilege",
                description: "更新测试专用",
                policy: "allow if { true }"
            )
        ]).get()
        let privilegeDTO = privileges[0]
        let privilegeId = privilegeDTO.id
        
        // 1. 测试更新 name 和 description (常量形式)
        let updater1 = PM<ResourceList>.PrivilegeDTO<DTO.Prepare>.Updater(privilegeId: privilegeId)
            .update(name: "Updated Name")
            .update(description: "Updated Description")
        
        let updated1 = try await m.privilege.update(with: updater1).get()
        #expect(updated1.name == "Updated Name")
        #expect(updated1.description == "Updated Description")
        #expect(updated1.policy == "allow if { true }") // policy 不变
        print("HELLO")
        // 2. 测试更新 policy (常量形式)
        let updater2 = PM<ResourceList>.PrivilegeDTO<DTO.Prepare>.Updater(privilegeId: privilegeId)
            .update(policy: "allow if { false }")
        print("HELLO2")
        let updated2 = try await m.privilege.update(with: updater2).get()
        #expect(updated2.name == "Updated Name") // name 保持上次更新的值
        #expect(updated2.policy == "allow if { false }")
        
        // 3. 测试依赖原值的更新 (闭包形式)
        let updater3 = PM<ResourceList>.PrivilegeDTO<DTO.Prepare>.Updater(privilegeId: privilegeId)
            .update(name: { $0.name! + " - V2" })
            .update(policy: { _ in "allow if { input.operation == \"edit\" }" })
        
        let updated3 = try await m.privilege.update(with: updater3).get()
        #expect(updated3.name == "Updated Name - V2")
        #expect(updated3.policy == "allow if { input.operation == \"edit\" }")
        
        // 清理
        try await m.privilege.delete(policy: updated3).get()
    }

    @Test("完整测试修改资源信息")
    func resource_Update_Comprehensive() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file = FileResource(name: "comp_test.txt", path: "/tmp/comp.txt", isPrivate: false)
        let created: [QFileResource] = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<FileResource, DTO.Prepare>(data: file)
        ]).get()
        let resourceId = created[0].id
        
        // 1. 更新单个字段 (常量形式)
        let updater1 = PFileResource.Updater(resourceId: resourceId)
            .update(data: { q in
                var d = q.data
                d.isPrivate = true
                return d
            })
        
        let updated1: QFileResource = try await m.resource.update(with: updater1).get()
        #expect(updated1.data.isPrivate == true)
        #expect(updated1.data.name == "comp_test.txt")
        
        // 2. 更新整个 data 对象 (常量形式)
        let newFile = FileResource(name: "new_comp.txt", path: "/tmp/new_comp.txt", isPrivate: false)
        let updater2 = PFileResource.Updater(resourceId: resourceId)
            .update(data: newFile)
        
        let updated2: QFileResource = try await m.resource.update(with: updater2).get()
        #expect(updated2.data.name == "new_comp.txt")
        #expect(updated2.data.path == "/tmp/new_comp.txt")
        
        // 3. 依赖原值的更新 (闭包形式)
        let updater3 = PFileResource.Updater(resourceId: resourceId)
            .update(data: { q in
                var d = q.data
                d.name = q.data.name + " - Updated"
                return d
            })
        
        let updated3: QFileResource = try await m.resource.update(with: updater3).get()
        #expect(updated3.data.name == "new_comp.txt - Updated")
        
        // 4. 依赖原值更新整个 data (闭包形式)
        let updater4 = PFileResource.Updater(resourceId: resourceId)
            .update(data: { q in
                var d = q.data
                d.path = "/tmp/final.txt"
                return d
            })
        
        let updated4: QFileResource = try await m.resource.update(with: updater4).get()
        #expect(updated4.data.path == "/tmp/final.txt")
        #expect(updated4.data.name == "new_comp.txt - Updated") // 保持上次的名字
        
        // 清理
        try await m.resource.delete(ids: [resourceId]).get()
    }
    
    @Test("删除资源")
    func resource_Delete() async throws {
        let (_, m) = try await TestingShared.getSystem()
        let file = FileResource(name: "delete.txt", path: "/tmp/delete.txt", isPrivate: true)
        let resourceDTO: QFileResource = try await m.resource.create(resources: [
            PM<ResourceList>.ResourceDTO<FileResource, DTO.Prepare>(data: file)
        ]).get().first!
        
        // 删除资源
        try await m.resource.delete(ids: [resourceDTO.id]).get()
        
        // 验证删除
        let count = try await PModule.ResourceModel<FileResource>.query(on: m.db)
            .filter(\.$id == resourceDTO.id)
            .count()
        
        #expect(count == 0)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .userInfo
    }
}
