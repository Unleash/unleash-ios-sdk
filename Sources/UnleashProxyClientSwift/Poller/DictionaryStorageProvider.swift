import Foundation

public class DictionaryStorageProvider: StorageProvider {
    private var storage: [String: Toggle] = [:]
    private let queue = DispatchQueue(label: "com.unleash.storage", attributes: .concurrent)

    public init() {}

    public func set(values: [String: Toggle]) {
        queue.async(flags: .barrier){
            self.storage = values
        }
    }

    public func value(key: String) -> Toggle? {
        queue.sync {
            return self.storage[key]
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            self.storage = [:]
        }
    }
}
