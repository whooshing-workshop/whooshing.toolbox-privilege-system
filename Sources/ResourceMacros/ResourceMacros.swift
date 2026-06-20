@_exported import ResourceDefine

/// 为 `Resource` 类型自动生成 `json` 和 `mirrors` 的实现。
///
/// 该宏会扫描结构体中所有存储属性，自动合成：
/// - `var json: [String: AnyCodable]` — 将每个属性转换为 AnyCodable 并以属性名作为 key
/// - `static var mirrors: [PartialKeyPath<Self>: [String]]` — 将每个属性的 KeyPath 映射到其 JSON 路径
///
/// 用法示例：
/// ```swift
/// @Resource
/// struct FileResource: Resource {
///     typealias ResourceType = ResourceList
///     typealias Operations = FileOperation
///     static let type: ResourceList = .file
///     var name: String
///     var path: String
///     var isPrivate: Bool
/// }
/// ```
///
/// 将展开为：
/// ```swift
/// extension FileResource: Resource {
///     var json: [String: AnyCodable] {
///         [
///             "name": AnyCodable(name),
///             "path": AnyCodable(path),
///             "isPrivate": AnyCodable(isPrivate),
///         ]
///     }
///     static var mirrors: [PartialKeyPath<Self>: [String]] {
///         [
///             \.name: ["name"],
///             \.path: ["path"],
///             \.isPrivate: ["isPrivate"],
///         ]
///     }
/// }
/// ```
///
@attached(extension, conformances: Resource, names: named(json), named(mirrors))
public macro Resource() = #externalMacro(
    module: "MacroImplements",
    type: "ResourceMacro"
)
