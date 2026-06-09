import Vapor
import Testing
@testable import PrivilegeSystem
@testable import PrivilegeModule
@testable import Query

@Suite("Query 模块测试集", .serialized, .enabled(if: TestingShared.dbListening && TestingShared.opaListening))
struct QueryTests {
    
    @Test("开始测试")
    func start() async throws {
        while await TestingShared.testStage != .query {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
    }
    
    @Test("基本过滤 (Filter)")
    func testFilter() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let email = "user1@example.com" // 使用 AccountTests 中创建的邮箱
        
        let user = try await s.query(QUser.self)
            .filter(\.email == email)
            .first()
            
            
        #expect(user != nil)
        #expect(user?.email == email)
    }
    
    @Test("连接查询 (Join)")
    func testJoin() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // Join User 和 UserInfo
        let results = try await s.query(QUser.self)
            .join(QUserInfo.self, on: \QUser.id == \QUserInfo.userId)
            .first()
            
            
        // 如果有匹配的数据，results 不为 nil
        // 这里只是验证 API 是否能正常执行不报错
        print("Join result: \(String(describing: results))")
    }
    
    @Test("分组查询 (Group)")
    func testGroup() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 测试 OR 条件
        let results = try await s.query(QUser.self)
            .group(.or) { group in
                group.filter(\.email == "user1@example.com")
                group.filter(\.email == "user2@gmail.com")
            }
            .page(with: 1, size: 10)
            
            
        print("Group result count: \(results.items.count)")
    }
    
    @Test("分页查询 (Pagination)")
    func testPagination() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let page = try await s.query(QUser.self)
            .page(with: 1, size: 2)
            
            
        #expect(page.items.count <= 2)
        #expect(page.metadata.page == 1)
        #expect(page.metadata.per == 2)
    }
    
    @Test("分块查询 (Chunk)")
    func testChunk() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        class SafeCounter: @unchecked Sendable {
            private let lock = NSLock()
            var value = 0
            func add(_ n: Int) {
                lock.lock()
                defer { lock.unlock() }
                value += n
            }
        }
        let counter = SafeCounter()
        
        try await s.query(QUser.self)
            .chunk(max: 2) { res in
                counter.add(res.count)
                print("Chunked \(res.count) items")
            }.get()
            
            
        print("Total items chunked: \(counter.value)")
    }
    
    @Test("其他 DTO 查询")
    func testOtherDTOs() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        // 查询 Domain
        let domain = try await s.query(QDomain.self)
            .filter(\.name == "GlobalScope")
            .first()
            
            
        print("Domain result: \(String(describing: domain))")
        
        // 查询 Group
        let group = try await s.query(QGroup.self)
            .filter(\.name == "AdministratorGroup")
            .first()
            
            
        print("Group result: \(String(describing: group))")
    }
    
    @Test("排序查询 (Sort)")
    func testSort() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let users = try await s.query(QUser.self)
            .sort(\.email, .descending)
            .page(with: 1, size: 10)
            
            
        print("Sorted users: \(users.items.map { $0.email })")
    }
    
    @Test("聚合查询 (Aggregate)")
    func testAggregate() async throws {
        let (s, _) = try await TestingShared.getSystem()
        
        let count = try await s.query(QUser.self).count()
        print("Total users count: \(count)")
        
        #expect(count >= 0)
    }
    
    @MainActor
    @Test("测试结束")
    func end() async throws {
        TestingShared.testStage = .policy
    }
}
