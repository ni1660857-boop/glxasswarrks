import XCTest
@testable import LiquidGlass

final class SecurityManagerTests: XCTestCase {
    
    var securityManager: SecurityManager!
    
    override func setUp() async throws {
        securityManager = SecurityManager.shared
        // Clear any previous state
        await securityManager.clearAllViolations()
    }
    
    // MARK: - Domain Validation Tests
    
    func testValidateAllowedDomain() async throws {
        let url = URL(string: "https://tidal.kinoplus.online/search")!
        
        // Should not throw
        try await securityManager.validateModuleURL(url, moduleId: "im-miserable")
    }
    
    func testValidateBlockedDomain() async {
        let url = URL(string: "https://malicious-site.com/stream")!
        
        do {
            try await securityManager.validateModuleURL(url, moduleId: "im-miserable")
            XCTFail("Should throw for blocked domain")
        } catch let error as SecurityError {
            if case .domainNotAllowed = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testValidateHTTPSRequired() async {
        let url = URL(string: "http://tidal.kinoplus.online/search")!
        
        do {
            try await securityManager.validateModuleURL(url, moduleId: "im-miserable")
            XCTFail("Should throw for HTTP URL")
        } catch let error as SecurityError {
            if case .insecureConnection = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testValidateBlockedScheme() async {
        let url = URL(string: "file:///etc/passwd")!
        
        do {
            try await securityManager.validateModuleURL(url, moduleId: "test")
            XCTFail("Should throw for file scheme")
        } catch let error as SecurityError {
            if case .blockedScheme = error {
                // Expected
            } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Policy Violation Tests
    
    func testPolicyViolationRecorded() async throws {
        let url = URL(string: "https://blocked-domain.com/api")!
        
        do {
            try await securityManager.validateModuleURL(url, moduleId: "test-module")
        } catch {
            // Expected
        }
        
        let violations = await securityManager.getViolations(forModuleId: "test-module")
        XCTAssertFalse(violations.isEmpty)
        XCTAssertEqual(violations.first?.moduleId, "test-module")
    }
    
    func testClearModuleViolations() async throws {
        // Generate a violation
        let url = URL(string: "https://blocked.com/api")!
        try? await securityManager.validateModuleURL(url, moduleId: "test-clear")
        
        // Clear it
        await securityManager.clearViolations(forModuleId: "test-clear")
        
        let violations = await securityManager.getViolations(forModuleId: "test-clear")
        XCTAssertTrue(violations.isEmpty)
    }
    
    // MARK: - Rate Limiting Tests
    
    func testRateLimitNotActive() async {
        let isLimited = await securityManager.isRateLimited(moduleId: "new-module")
        XCTAssertFalse(isLimited)
    }
    
    func testRateLimitActive() async {
        await securityManager.recordRateLimit(moduleId: "rate-test", retryAfter: 60)
        
        let isLimited = await securityManager.isRateLimited(moduleId: "rate-test")
        XCTAssertTrue(isLimited)
        
        let remaining = await securityManager.rateLimitRemaining(moduleId: "rate-test")
        XCTAssertNotNil(remaining)
        XCTAssertGreaterThan(remaining!, 0)
    }
    
    // MARK: - URL Sanitization Tests
    
    func testSanitizeURLRemovesSensitiveParams() async {
        let url = URL(string: "https://api.example.com/track?id=123&token=secret&key=apikey")!
        
        let sanitized = await securityManager.sanitizeURL(url)
        
        XCTAssertFalse(sanitized.absoluteString.contains("secret"))
        XCTAssertFalse(sanitized.absoluteString.contains("apikey"))
        XCTAssertTrue(sanitized.absoluteString.contains("id=123"))
    }
    
    func testSanitizeURLPreservesNormalParams() async {
        let url = URL(string: "https://api.example.com/search?query=test&limit=20")!
        
        let sanitized = await securityManager.sanitizeURL(url)
        
        XCTAssertTrue(sanitized.absoluteString.contains("query=test"))
        XCTAssertTrue(sanitized.absoluteString.contains("limit=20"))
    }
}
