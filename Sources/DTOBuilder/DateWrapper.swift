import Foundation
import AnyCodable

package struct DateWrapper: Codable, Sendable {
    package let year: Int
    package let month: Int
    package let day: Int
    package let hour: Int
    package let minute: Int
    package let second: Int
    package let millisecond: Int
    package let microsecond: Int
    package let weekday: String
    package let iso8601: String
    package let raw: Int64

    package init(_ date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
        
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
        self.second = components.second ?? 0
        
        // 毫秒与微秒转换
        let nano = components.nanosecond ?? 0
        self.millisecond = nano / 1_000_000
        self.microsecond = (nano / 1_000) % 1_000 // 对应 PG 中用微秒取模的效果
        
        // 星期名称 (FMDay 格式)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full weekday name
        self.weekday = formatter.string(from: date)
        
        // ISO8601 格式化 (包含微秒和 Z)
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.iso8601 = isoFormatter.string(from: date)
        
        // Raw: 纳秒级别的 Unix 时间戳
        self.raw = Int64(date.timeIntervalSince1970 * 1_000_000_000)
    }
    
    package var date: Date {
        .init(timeIntervalSince1970: Double(raw) / 1_000_000_000)
    }
}

public struct DateWrapperEncoder: Sendable {
    static let sharedWrapperEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, e in
            var container = e.singleValueContainer()
            try container.encode(DateWrapper(date))
        }
        return encoder
    }()
    
    static let sharedWrapperDecoder = JSONDecoder()
    
    static func json<T: Encodable>(from model: T) throws -> [String: AnyCodable] {
        let jsonData = try Self.sharedWrapperEncoder.encode(model)
        
        // 2. 二期解码：原地复活为满足你核心网关需要的动态字典
        return try Self.sharedWrapperDecoder.decode([String: AnyCodable].self, from: jsonData)
    }
}

public protocol DateWrapperModel: Encodable, Sendable {}

public extension DateWrapperModel {
    func wrappedJson() throws -> [String: AnyCodable] {
        try DateWrapperEncoder.json(from: self)
    }
}
