import Foundation
import CryptoKit

// MARK: - Security Manager

/// Manages security policies for module sandboxing and verification.
/// Enforces domain allowlists, module signing, and policy violations.
public actor SecurityManager {
    
    // MARK: - Singleton
    
    public static let shared = SecurityManager()
    
    // MARK: - Configuration
    
    /// Global allowed domains (in addition to module-specific domains)
    private let globalAllowedDomains: Set<String> = [
        "tidal.kinoplus.online",
        "resources.tidal.com",
        "api.spotify.com",
        "i.scdn.co"  // Spotify images
    ]
    
    /// Blocked URL schemes
    private let blockedSchemes: Set<String> = [
        "file",
        "ftp",
        "telnet",
        "data"
    ]
    
    /// Minimum TLS version required
    private let minimumTLSVersion: String = "TLSv1.2"
    
    // MARK: - State
    
    private var moduleAllowedDomains: [String: Set<String>] = [:]
    private var policyViolations: [PolicyViolation] = []
    private var trustedCertificates: [String: Data] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // In production, load certificates from a secure bundle
        // For now, we'll pre-register a test certificate
        
        // Add built-in module certificate
        let builtInCertId = "com.liquidglass.builtin"
        trustedCertificates[builtInCertId] = "BUILTIN_MODULE_TRUSTED".data(using: .utf8)!
    }
    
    // MARK: - Domain Validation
    
    /// Register allowed domains for a module
    public func registerModuleDomains(moduleId: String, domains: [String]) {
        moduleAllowedDomains[moduleId] = Set(domains)
    }
    
    /// Validate a URL against module and global allowlists
    public func validateModuleURL(_ url: URL, moduleId: String) throws {
        // Check scheme
        guard let scheme = url.scheme?.lowercased() else {
            throw SecurityError.invalidURL("Missing URL scheme")
        }
        
        if blockedSchemes.contains(scheme) {
            let violation = PolicyViolation(
                moduleId: moduleId,
                reason: "Blocked URL scheme: \(scheme)",
                url: url,
                timestamp: Date()
            )
            policyViolations.append(violation)
            throw SecurityError.blockedScheme(scheme)
        }
        
        // Require HTTPS
        guard scheme == "https" else {
            let violation = PolicyViolation(
                moduleId: moduleId,
                reason: "Non-HTTPS URL: \(url)",
                url: url,
                timestamp: Date()
            )
            policyViolations.append(violation)
            throw SecurityError.insecureConnection
        }
        
        // Check domain
        guard let host = url.host?.lowercased() else {
            throw SecurityError.invalidURL("Missing host")
        }
        
        let isDomainAllowed = isDomainAllowed(host, forModuleId: moduleId)
        
        if !isDomainAllowed {
            let violation = PolicyViolation(
                moduleId: moduleId,
                reason: "Domain not in allowlist: \(host)",
                url: url,
                timestamp: Date()
            )
            policyViolations.append(violation)
            throw SecurityError.domainNotAllowed(host)
        }
    }
    
    /// Check if a domain is allowed for a module
    private func isDomainAllowed(_ domain: String, forModuleId moduleId: String) -> Bool {
        // Check global allowlist
        if globalAllowedDomains.contains(where: { domain.hasSuffix($0) }) {
            return true
        }
        
        // Check module-specific allowlist
        if let moduleDomains = moduleAllowedDomains[moduleId] {
            return moduleDomains.contains(where: { domain.hasSuffix($0) })
        }
        
        return false
    }
    
    // MARK: - Module Signature Verification
    
    /// Verify a module's cryptographic signature
    public func verifyModuleSignature(_ signature: ModuleSignature) throws -> Bool {
        // Get trusted certificate
        guard let certificateData = trustedCertificates[signature.certificateId] else {
            throw SecurityError.untrustedCertificate(signature.certificateId)
        }
        
        // Verify signature age (reject if too old)
        let maxAge: TimeInterval = 365 * 24 * 60 * 60 // 1 year
        if Date().timeIntervalSince(signature.timestamp) > maxAge {
            throw SecurityError.expiredSignature
        }
        
        // Verify signature using the certificate's public key
        // In production, this would verify against the actual certificate
        // For now, we'll do a simplified check
        
        switch signature.algorithm {
        case "SHA256withRSA", "SHA256":
            // Verify SHA256 digest
            _ = SHA256.hash(data: certificateData)
            // In production: verify signature.data against hash using public key
            return !signature.data.isEmpty
            
        default:
            throw SecurityError.unsupportedAlgorithm(signature.algorithm)
        }
    }
    
    /// Add a trusted certificate
    public func addTrustedCertificate(id: String, data: Data) {
        trustedCertificates[id] = data
    }
    
    // MARK: - Policy Violations
    
    /// Get all policy violations
    public func getViolations() -> [PolicyViolation] {
        policyViolations
    }
    
    /// Get violations for a specific module
    public func getViolations(forModuleId moduleId: String) -> [PolicyViolation] {
        policyViolations.filter { $0.moduleId == moduleId }
    }
    
    /// Clear violations for a module
    public func clearViolations(forModuleId moduleId: String) {
        policyViolations.removeAll { $0.moduleId == moduleId }
    }
    
    /// Clear all violations
    public func clearAllViolations() {
        policyViolations.removeAll()
    }
    
    // MARK: - URL Sanitization
    
    /// Sanitize a URL by removing sensitive parameters
    public func sanitizeURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        
        // Remove sensitive query parameters
        let sensitiveParams: Set<String> = [
            "token", "key", "secret", "password", "auth", "session", "sig", "signature"
        ]
        
        components.queryItems = components.queryItems?.filter { item in
            !sensitiveParams.contains(item.name.lowercased())
        }
        
        return components.url ?? url
    }
    
    // MARK: - Rate Limiting
    
    private var rateLimitState: [String: RateLimitState] = [:]
    
    /// Check if a module is rate limited
    public func isRateLimited(moduleId: String) -> Bool {
        guard let state = rateLimitState[moduleId] else { return false }
        return Date() < state.unlocksAt
    }
    
    /// Record a rate limit hit
    public func recordRateLimit(moduleId: String, retryAfter: TimeInterval) {
        rateLimitState[moduleId] = RateLimitState(
            unlocksAt: Date().addingTimeInterval(retryAfter),
            hitCount: (rateLimitState[moduleId]?.hitCount ?? 0) + 1
        )
    }
    
    /// Get remaining rate limit time
    public func rateLimitRemaining(moduleId: String) -> TimeInterval? {
        guard let state = rateLimitState[moduleId] else { return nil }
        let remaining = state.unlocksAt.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
}

// MARK: - Supporting Types

/// Security-related errors
public enum SecurityError: LocalizedError {
    case invalidURL(String)
    case blockedScheme(String)
    case insecureConnection
    case domainNotAllowed(String)
    case untrustedCertificate(String)
    case expiredSignature
    case unsupportedAlgorithm(String)
    case signatureVerificationFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let reason):
            return "Invalid URL: \(reason)"
        case .blockedScheme(let scheme):
            return "Blocked URL scheme: \(scheme)"
        case .insecureConnection:
            return "HTTPS required for all connections"
        case .domainNotAllowed(let domain):
            return "Domain not in allowlist: \(domain)"
        case .untrustedCertificate(let id):
            return "Untrusted certificate: \(id)"
        case .expiredSignature:
            return "Module signature has expired"
        case .unsupportedAlgorithm(let algorithm):
            return "Unsupported signing algorithm: \(algorithm)"
        case .signatureVerificationFailed:
            return "Signature verification failed"
        }
    }
}

/// Recorded policy violation
public struct PolicyViolation: Identifiable, Sendable {
    public let id = UUID()
    public let moduleId: String
    public let reason: String
    public let url: URL?
    public let timestamp: Date
}

/// Rate limit tracking state
private struct RateLimitState {
    let unlocksAt: Date
    let hitCount: Int
}
