import Fluent
import Foundation
import Censor
import ErrorHandle

public typealias CensorModel = Censor

public extension DTO {
    struct Censor<T: Status>: Sendable {
        public let expression: String
        public let map: CensorModel.Map
        @Protect() public internal(set) var ast: CensorModel.AST
        
        init(
            _expression: String,
            _map: CensorModel.Map
        ) {
            self.expression = _expression
            self.map = _map
        }
    }
}

public extension DTO.Censor where T == DTO.Prepare {
    init(
        expression: String,
        ast: Censor.AST,
        map: Censor.Map
    ) {
        self = Self.init(_expression: expression, _map: map)
        self.ast = ast
    }
}

extension DTO.Censor where T == DTO.Queried {
    static func make<G>(from model: G) -> Res<Self, PrivilegeSystem.Errcase> where G: ACLInterface {
        .init(throws: .censorDTOFailed, category: .internal) {
            var n = Self.init(
                _expression: model.expression,
                _map: model.map
            )
            return n
        }
    }
}
