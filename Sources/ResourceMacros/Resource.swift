import Foundation
import ErrorHandle
import Logging
import LoggingAdvanced
@preconcurrency import AnyCodable

/// 可参与模块级鉴权的类型化资源。
///
/// 业务服务中每一种需要受保护的资源形状都可以实现 `Resource`。资源会被转换为
/// JSON 传给 OPA，也可以通过 `PrivilegeModule.ResourceController` 持久化。
///
/// ```swift
/// enum FileOperation: String, OperationList {
///     case read
///     case write
/// }
///
/// @Resource
/// struct FileResource: Hashable {
///     typealias ResourceType = ResourceList
///     typealias Operations = FileOperation
///
///     static let type: ResourceList = .file
///     var name: String
///     var path: String
/// }
/// ```
///
/// 使用 `@Resource` 宏时，类型只需要声明存储属性和关联类型；宏会自动生成
/// `json` 和 `mirrors`。
public protocol Resource: Sendable, Codable, Hashable, Loggerable, CustomStringConvertible {
    /// 模块内所有资源类别的枚举类型。
    associatedtype ResourceType: ResourceTypeList
    /// 该资源形状支持的操作枚举类型。
    associatedtype Operations: OperationList
    /// 该资源在模块数据库中保存的资源类别。
    static var type: ResourceType { get }
    
    /// 资源名称，用于日志和通用资源 DTO。
    var name: String { get }
    
    /// 传给 OPA `input.resource` 的 JSON 表示。
    var json: [String: AnyCodable] { get }
    /// Swift KeyPath 到 JSON 路径的映射，用于局部 JSONB 更新。
    static var mirrors: [PartialKeyPath<Self>: [String]] { get }
}

/// 某种资源类型的封闭操作列表。
///
/// 使用 `String` 作为 RawValue，便于把操作作为 `input.operation` 传给 OPA。
public protocol OperationList: Sendable, Codable, CaseIterable, RawRepresentable
where Self.RawValue == String {}

/// 一个资源权限模块拥有的封闭资源类别列表。
///
/// 每个 `PrivilegeModule<ResourceList>` 都会用一个具体的 `ResourceTypeList`
/// 特化自己的资源数据库模型。
public protocol ResourceTypeList: Sendable, Codable, CaseIterable, RawRepresentable, Hashable
where Self.RawValue == String {}

public extension Resource {
    /// 资源 JSON 的格式化字符串表示。
    var description: String {
        formatJson(self.json)
    }
    
    /// 实例层面对 `Self.type` 的便捷访问。
    var rtype: ResourceType {
        Self.type
    }
}

/// 传入权限仲裁的类型擦除操作值。
///
/// `AnyOperation` 允许 `Arbitrator.judge` 接收不同资源类型的操作枚举，同时保留
/// OPA 需要的原始操作字符串。
///
/// ```swift
/// let operation = AnyOperation(op: FileOperation.read)
/// ```
public struct AnyOperation: Sendable, Decodable, Loggerable, CustomStringConvertible {
    /// 发送给 OPA `input.operation` 的原始操作字符串。
    public let rawValue: String
    
    /// 从类型化操作枚举创建一个擦除后的操作值。
    public init<T: OperationList>(op: T) {
        self.rawValue = op.rawValue
    }
    
    /// 原始操作字符串。
    public var description: String {
        self.rawValue
    }
    
    public var summaryDescription: String {
        self.rawValue
    }
    
    public var logDescription: String {
        self.rawValue
    }
}
