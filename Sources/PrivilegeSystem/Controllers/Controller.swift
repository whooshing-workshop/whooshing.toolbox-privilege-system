import Fluent

protocol Controller: Sendable {
    var db: PrivilegeSystem.PGDatabase { get }
    var eventLoop: EventLoop { get }
    
    init(system: PrivilegeSystem)
}
