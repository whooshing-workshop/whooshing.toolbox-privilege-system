import ErrorHandle
import ACL

public struct PrivilegeInterpreter {
    
    public let globals: [String: any Resource] = [:]
    
    public func execute<R: Resource>(
        with expression: PrivilegeExpression,
        for resource: R,
        operations: Set<R.Op>,
        in module: PriviliegeModule
    ) -> Res<Bool, Errcase> {
        
        .success(true)
    }
}
