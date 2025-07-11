import XCTest
@testable import UnleashProxyClientSwift

class ThreadSafetyTest: XCTestCase {

    func testThreadSafety() {
        // This test demonstrates the thread safety issues in UnleashClient
        // by simulating concurrent access from multiple threads to the same client instance

        // Run the test 10 times in a row to increase chances of detecting race conditions
        for run in 1...10 {
            print("\n=== Starting test run \(run) of 10 ===\n")

            // Create a shared client instance
            let unleashClient = UnleashClientBase(
                unleashUrl: "https://sandbox.getunleash.io/enterprise/api/frontend",
                clientKey: "SDKIntegration:development.f0474f4a37e60794ee8fb00a4c112de58befde962af6d5055b383ea3",
                appName: "testIntegration"
            )

            // Start the client on the main thread
            unleashClient.start()

            // Create a dispatch group to wait for all operations to complete
            let group = DispatchGroup()

            // Simulate multiple threads checking feature flags simultaneously
            for i in 1...5 {
                // Background thread 1: Repeatedly check isEnabled
                group.enter()
                DispatchQueue.global().async {
                    for _ in 1...100 {
                        // This can crash due to race conditions in isEnabled
                        let isEnabled = unleashClient.isEnabled(name: "enabled-feature")
                        print("Thread \(i): Flag is \(isEnabled ? "enabled" : "disabled")")

                        // Small sleep to increase chance of thread interleaving
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    group.leave()
                }

                // Background thread 2: Repeatedly check variants
                group.enter()
                DispatchQueue.global().async {
                    for _ in 1...100 {
                        // This can crash due to race conditions in getVariant
                        let variant = unleashClient.getVariant(name: "enabled-feature")
                        print("Thread \(i): Variant is \(variant.name)")

                        // Small sleep to increase chance of thread interleaving
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    group.leave()
                }

                // Background thread 3: Update context occasionally
                group.enter()
                DispatchQueue.global().async {
                    for j in 1...10 {
                        // This can crash due to race conditions when updating context
                        unleashClient.updateContext(context: [
                            "userId": "user-\(j)",
                            "sessionId": "session-\(j)"
                        ])
                        print("Thread \(i): Updated context with userId user-\(j)")

                        // Sleep longer between context updates
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    group.leave()
                }
            }

            // Add a specific test for dataRaceTest flag, similar to the integration test
            var enabledCount = 0
            for i in 1...15000 {
                let result = unleashClient.isEnabled(name: "dataRaceTest")
                if result {
                    enabledCount += 1
                }

                // Print progress every 1000 iterations
                if i % 1000 == 0 {
                    print("Completed \(i) dataRaceTest checks...")
                }
            }
            print("dataRaceTest results: enabled \(enabledCount) times out of 15000 checks")

            // Wait for all operations to complete
            group.wait()
            print("Run \(run) completed")

            // Clean up
            unleashClient.stop()

            // Add a small delay between runs to ensure resources are properly released
            if run < 10 {
                print("Waiting before starting next run...")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        print("\n=== All 10 test runs completed ===\n")
    }
}
