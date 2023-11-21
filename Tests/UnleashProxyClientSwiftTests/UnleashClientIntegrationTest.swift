import XCTest
@testable import UnleashProxyClientSwift

class UnleashIntegrationTests: XCTestCase {

    var unleashClient: UnleashProxyClientSwift.UnleashClientBase!
    let featureName = "enabled-feature"
    
    override func setUpWithError() throws {
        unleashClient = UnleashProxyClientSwift.UnleashClientBase(
            unleashUrl: "https://sandbox.getunleash.io/enterprise/api/frontend",
            clientKey: "SDKIntegration:development.f0474f4a37e60794ee8fb00a4c112de58befde962af6d5055b383ea3",
            refreshInterval: 15,
            appName: "testIntegration",
            context: ["clientId": "disabled"]
        )
    }

    override func tearDownWithError() throws {
        unleashClient.stop()
    }

    func testUserJourneyHappyPath() {
        let expectation = self.expectation(description: "Waiting for client updates")
        
        XCTAssertEqual(unleashClient.context.toMap(), ["environment": "default", "clientId": "disabled", "appName": "testIntegration"])

        unleashClient.subscribe(name: "ready", callback: {
            XCTAssertFalse(self.unleashClient.isEnabled(name: self.featureName), "Feature should be disabled")

            let variant = self.unleashClient.getVariant(name: self.featureName)
            XCTAssertNotNil(variant, "Variant should not be nil")
            XCTAssertFalse(variant.enabled, "Variant should be disabled")

            self.unleashClient.updateContext(context: ["clientId": "enabled"]);
        })
        
        unleashClient.subscribe(name: "update", callback: {
            XCTAssertTrue(self.unleashClient.isEnabled(name: self.featureName), "Feature should be enabled")
            let variant = self.unleashClient.getVariant(name: self.featureName)
            XCTAssertTrue(variant.enabled, "Variant should be enabled")
            XCTAssert(variant.name == "feature-variant")
            
            expectation.fulfill()
        });

        unleashClient.start()

        wait(for: [expectation], timeout: 5)
    }
    
}
