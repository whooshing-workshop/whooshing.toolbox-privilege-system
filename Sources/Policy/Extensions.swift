import Foundation
import OrderedCollections

package extension AnyHashable {
    init?<T: Hashable>(obj: T?) {
        guard let o = obj else { return nil }
        self = Self.init(o)
    }
}

public struct EnumeratedOrderedSet<Element>: Hashable, Equatable where Element: Hashable & Equatable {
    public let offset: Int
    public let element: Element
}

extension EnumeratedOrderedSet: Sendable where Element: Sendable {}

public extension OrderedSet {
    /// 映射并直接返回一个新的 OrderedSet（会自动去重）
    func mapToSet<T: Hashable>(_ transform: (Element) throws -> T) rethrows -> OrderedSet<T> {
        var result = OrderedSet<T>()
        for element in self {
            try result.append(transform(element))
        }
        return result
    }
    
    /// 闭包返回一个标准的 Sequence（如 Array、Set 等）
    /// 映射、拍平并直接返回一个新的 OrderedSet（会自动去重并保持首次出现的顺序）
    func flatMapToSet<S: Sequence>(_ transform: (Element) throws -> S) rethrows -> OrderedSet<S.Element> where S.Element: Hashable {
        var result = OrderedSet<S.Element>()
        for element in self {
            let sequence = try transform(element)
            result.append(contentsOf: sequence)
        }
        return result
    }
    
    /// 闭包返回一个 Optional（即 Swift 5 之后的 compactMap）
    /// 过滤掉 nil、解包并直接返回一个新的 OrderedSet
    func compactMapToSet<T: Hashable>(_ transform: (Element) throws -> T?) rethrows -> OrderedSet<T> {
        var result = OrderedSet<T>()
        for element in self {
            if let unwrapped = try transform(element) {
                result.append(unwrapped)
            }
        }
        return result
    }
    
    func enumeratedSet() -> OrderedSet<EnumeratedOrderedSet<Element>> {
        .init(
            enumerated().map { i, v in
                EnumeratedOrderedSet<Element>.init(offset: i, element: v)
            }
        )
    }
}
