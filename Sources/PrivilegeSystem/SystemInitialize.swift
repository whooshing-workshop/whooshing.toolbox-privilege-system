import OPA
import ErrorHandle
import Foundation
import Collections
import FluentPostgresDriver
import Logging
import LoggingAdvanced
@preconcurrency import AnyCodable

extension PrivilegeSystem {
    func systemInitialize(dbConfigure: SQLPostgresConfiguration, logger: Logger) async throws(BscError<Errcase>) {
        let regos = try loadRegos(logger: logger)
        logger.info("Rego 脚本加载完成")
        let sqls = try loadSQLs(logger: logger)
        logger.info("SQL 函数加载完成")
        
        // SQL 函数注入
        for (_, sql) in sqls {
            _ = try await logger.required(throws: Errcase.databaseInitFailed, "将 SQL Function 注入数据库失败", category: .internal) {
                try await self.db.query(sql).get()
            }
        }
        
        guard
            let hostname = dbConfigure.coreConfiguration.host,
            let port = dbConfigure.coreConfiguration.port,
            let database = dbConfigure.coreConfiguration.database,
            let password = dbConfigure.coreConfiguration.password
        else {
            throw logger.errThrow(Errcase.databaseInitFailed.d("连接参数缺失，无法初始化 REGO", category: .external))
        }
        
        // REGO 数据库连接参数注入
        try await logger.required(throws: Errcase.databaseInitFailed, "向 OPA 注入 数据库连接参数 时失败", category: .internal) {
            _ = try await opa.data.save(
                on: "/",
                ifNoneMatch: nil,
                data: [
                    "pg": [
                        "connection": "host=\(hostname) port=\(port) dbname=\(database) user=\(dbConfigure.coreConfiguration.username) password=\(password)"
                    ]
                ]
            )
        }
        
        // REGO 基本命令注入
        for (path, content) in regos {
            try await logger.required(throws: Errcase.databaseInitFailed, "向 OPA 注入 REGO 基本命令 时失败", category: .internal) {
                _ = try await opa.policy.save(by: path, content: content)
            }
        }
        
        logger.info("系统加载完成")
    }
    
    private func loadRegos(logger: Logger) throws(BscError<Errcase>) -> OrderedDictionary<String, String> {
        guard let rootURL = Bundle.module.resourceURL?.appendingPathComponent("Regos") else {
            throw logger.errThrow(Errcase.regoLoadFailed.d("未找到 Bundle", category: .internal))
        }
        
        var allURLs: [URL] = []
        
        // 1. 收集所有符合条件的 URL
        let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "rego" {
                allURLs.append(fileURL)
            }
        }
        
        // 2. 根据文件名中的数字前缀进行排序
        // 逻辑：提取文件名 -> 找第一个 "-" 之前的数字 -> 转为 Int 比较
        allURLs.sort { url1, url2 in
            let n1 = extractPrefixNumber(from: url1.lastPathComponent)
            let n2 = extractPrefixNumber(from: url2.lastPathComponent)
            return n1 < n2
        }
        
        // 3. 构建有序字典并清洗 Key
        var policies = OrderedDictionary<String, String>()
        for fileURL in allURLs {
            let relativePath = fileURL.path.replacingOccurrences(of: rootURL.path + "/", with: "")
            
            // 处理 Key:
            // a. 分解路径组件
            // b. 对每一部分移除 "1-" 这种前缀
            // c. 用 "." 重新连接
            let components = relativePath.deletingPathExtension().components(separatedBy: "/")
            let cleanKey = components.map { stripPrefix($0) }.joined(separator: ".")
            
            policies[cleanKey] = try logger.required(throws: Errcase.regoLoadFailed, "加载 Rego 内容失败", category: .internal) {
                try String(contentsOf: fileURL)
            }
        }
        
        return policies
    }
    
    private func loadSQLs(logger: Logger) throws(BscError<Errcase>) -> OrderedDictionary<String, String> {
        guard let rootURL = Bundle.module.resourceURL?.appendingPathComponent("SQLFunctions") else {
            throw logger.errThrow(Errcase.sqlLoadFailed.d("未找到 Bundle", category: .internal))
        }
        
        var allURLs: [URL] = []
        
        // 2. 递归查找所有 .sql 文件
        let enumerator = FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: [.isRegularFileKey])
        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension == "sql" {
                allURLs.append(fileURL)
            }
        }
        
        // 3. 仅根据文件名开头的数字进行排序
        allURLs.sort { url1, url2 in
            extractPrefixNumber(from: url1.lastPathComponent) < extractPrefixNumber(from: url2.lastPathComponent)
        }
        
        // 4. 构建字典，Key 只取文件名（去掉前缀和 .sql）
        var sqlDict = OrderedDictionary<String, String>()
        for fileURL in allURLs {
            let fileName = fileURL.deletingPathExtension().lastPathComponent
            let cleanKey = stripPrefix(fileName)
            
            sqlDict[cleanKey] = try logger.required(throws: Errcase.sqlLoadFailed, "加载 SQL 内容失败", category: .internal) {
                try String(contentsOf: fileURL, encoding: .utf8)
            }
        }
        
        return sqlDict
    }
    
    /// 提取文件名开头的数字，例如 "12-pg.rego" -> 12
    private func extractPrefixNumber(from fileName: String) -> Int {
        let scanner = Scanner(string: fileName)
        // 扫描数字，如果扫描不到则默认为极大的数字（排在最后）
        if let number = scanner.scanInt() {
            return number
        }
        return Int.max
    }
    
    /// 移除字符串开头的数字和连字符，例如 "1-pg" -> "pg"
    private func stripPrefix(_ component: String) -> String {
        // 使用正则或简单的分割逻辑
        // 寻找第一个 "-" 的位置
        if let dashIndex = component.firstIndex(of: "-") {
            let prefix = component[..<dashIndex]
            // 确认前缀全是数字
            if prefix.allSatisfy({ $0.isNumber }) {
                return String(component[component.index(after: dashIndex)...])
            }
        }
        return component
    }
}

// 辅助扩展：为了保持代码整洁，给 String 增加一个类似 URL 的处理方法
extension String {
    func deletingPathExtension() -> String {
        guard let lastDotIndex = self.lastIndex(of: ".") else { return self }
        return String(self[..<lastDotIndex])
    }
}
