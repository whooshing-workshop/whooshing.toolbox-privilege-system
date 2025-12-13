import PrivilegeInterprete

public enum PropertyType {
    case vars
    case lets
    case propertyWrappers
}

public struct IncludeStrategy {
    public enum Key {
        case and, or
    }
    
    public let strategy: Key
    public let types: [PropertyType]
    
    public static func and(_ types: PropertyType...) -> Self {
        Self.init(strategy: .and, types: Array(types))
    }
    
    public static func or(_ types: PropertyType...) -> Self {
        Self.init(strategy: .or, types: Array(types))
    }
}

@attached(extension, conformances: Resource, names: named(vars), named(label))
public macro Resource(
    include: IncludeStrategy = .or(.propertyWrappers)
) = #externalMacro(
    module: "MacroImplements",
    type: "ResourceMacro"
)

@attached(extension, conformances: Label, names: named(vars))
public macro Label(
    include: IncludeStrategy = .or(.propertyWrappers)
) = #externalMacro(
    module: "MacroImplements",
    type: "LabelMacro"
)
