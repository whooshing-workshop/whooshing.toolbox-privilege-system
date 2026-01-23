import Foundation

extension Censor {
    enum Rule {
        /// 静态注册所有规则
        /// 当添加新规则时，请在此列表中追加实例
        static let all: [any Define] = [
            In()
        ]
        
        protocol Define: Sendable, CustomStringConvertible {
            /// 触发该规则的关键字
            var keyword: Censor.Keyword.Define { get }
            
            /// 规则名称 (用于 AST 记录)
            var name: String { get }
            
            var declare: FunctionDeclare { get }
            
            /// 解析逻辑
            /// - Parameter parser: 解析器实例
            /// - Returns: 解析生成的 AST 节点 (通常是 .rule(self, content))
            func parse(parser: Censor.Parser) -> Censor.AST?
        }
    }
}

public extension Censor {
    struct AnyRule: Sendable, CustomStringConvertible {
        public let keyword: Censor.Keyword.Define
        public let name: String
        public let description: String
        let declare: FunctionDeclare
        
        private let parseAction: @Sendable (Censor.Parser) -> Censor.AST?
        
        init<R: Rule.Define>(_ rule: R) {
            self.keyword = rule.keyword
            self.name = rule.name
            self.declare = rule.declare
            self.description = rule.description
            self.parseAction = rule.parse(parser:)
        }
        
        func parse(parser: Censor.Parser) -> Censor.AST? {
            parseAction(parser)
        }
    }
}
