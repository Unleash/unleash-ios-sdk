import Foundation
import SwiftEventBus

public class Metrics {
    let appName: String
    let metricsInterval: TimeInterval
    let clientKey: String
    typealias PosterHandler = (URLRequest, @escaping (Result<(Data, URLResponse), Error>) -> Void) -> Void
    let poster: PosterHandler
    let clock: () -> Date
    var disableMetrics: Bool
    var timer: DispatchSourceTimer?
    var bucket: Bucket
    let url: URL
    let customHeaders: [String: String]
    let connectionId: UUID

    private let queue: DispatchQueue

    init(appName: String,
         metricsInterval: TimeInterval,
         clock: @escaping () -> Date,
         disableMetrics: Bool = false,
         poster: @escaping PosterHandler,
         url: URL,
         clientKey: String,
         customHeaders: [String: String] = [:],
         connectionId: UUID,
         queue: DispatchQueue = DispatchQueue(label: "io.getunleash.metrics")) {
        self.appName = appName
        self.metricsInterval = metricsInterval
        self.clock = clock
        self.disableMetrics = disableMetrics
        self.poster = poster
        self.url = url
        self.clientKey = clientKey
        self.bucket = Bucket(clock: clock)
        self.customHeaders = customHeaders
        self.connectionId = connectionId
        self.queue = queue
    }

    func start() {
        if disableMetrics { return }

        queue.sync {
            self.timer?.cancel()
            self.timer = nil
        }

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + self.metricsInterval, repeating: self.metricsInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.sendMetrics()
        }
        timer.resume()

        queue.sync {
            self.timer = timer
        }
    }

    func stop() {
        queue.sync {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    func count(name: String, enabled: Bool) {
        if disableMetrics { return }

        queue.sync {
            var toggle = bucket.toggles[name] ?? ToggleMetrics()
            if enabled {
                toggle.yes += 1
            } else {
                toggle.no += 1
            }
            bucket.toggles[name] = toggle
        }
    }

    func countVariant(name: String, variant: String) {
        if disableMetrics { return }

        queue.sync {
            var toggle = bucket.toggles[name] ?? ToggleMetrics()
            toggle.variants[variant, default: 0] += 1
            bucket.toggles[name] = toggle
        }
    }

    func sendMetrics() {
        let localBucket: Bucket = queue.sync {
            bucket.closeBucket()
            let result = bucket
            bucket = Bucket(clock: clock)
            return result
        }

        guard !localBucket.isEmpty() else { return }

        do {
            let payload = MetricsPayload(appName: appName, instanceId: "swift", bucket: localBucket)
            let jsonPayload = try JSONSerialization.data(withJSONObject: payload.toJson())
            let request = createRequest(payload: jsonPayload)
            poster(request) { result in
                switch result {
                case .success(_):
                    SwiftEventBus.post("sent")
                case .failure(let error):
                    Printer.printMessage("Error sending metrics")
                    SwiftEventBus.post("error", sender: error)
                }
            }
        } catch {
            Printer.printMessage("Error preparing metrics for sending")
            SwiftEventBus.post("error", sender: error)
        }
    }

    func createRequest(payload: Data) -> URLRequest {
        var request = URLRequest(url: url.appendingPathComponent("client/metrics"))
        request.httpMethod = "POST"
        request.httpBody = payload
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("no-cache", forHTTPHeaderField: "Cache")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(clientKey, forHTTPHeaderField: "Authorization")
        request.addValue(appName, forHTTPHeaderField: "unleash-appname")
        request.addValue(connectionId.uuidString, forHTTPHeaderField: "unleash-connection-id")
        request.setValue("unleash-client-swift:\(LibraryInfo.version)", forHTTPHeaderField: "unleash-sdk")
        if !self.customHeaders.isEmpty {
            for (key, value) in self.customHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        return request
    }
}
