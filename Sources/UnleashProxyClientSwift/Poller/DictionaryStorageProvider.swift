import Foundation

public class DictionaryStorageProvider: StorageProvider {
    private var storage: [String: Toggle] = [:]
    private let lock = NSLock()

    public init() {}

    public func set(values: [String: Toggle]) {
        lock.lock()
        self.storage = values
        lock.unlock()
    }

    public func value(key: String) -> Toggle? {
        lock.lock()
        let result = self.storage[key]
        lock.unlock()
        return result
    }

    public func clear() {
        lock.lock()
        self.storage = [:]
        lock.unlock()
    }
}
