import Foundation
import Combine
import SwiftUI

// MARK: - Module Registry

/// Central registry for managing music source modules.
/// Handles module lifecycle, authentication, and security verification.
@MainActor
public final class ModuleRegistry: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var modules: [String: any MusicModule] = [:]
    @Published public private(set) var enabledModules: [any MusicModule] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: Error?
    
    // MARK: - Private Properties
    
    private let securityManager: SecurityManager
    private let networkLogger: NetworkLogger
    private let userDefaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    
    /// Approved module sources for remote loading
    private let approvedManifestURLs: [URL] = [
        // Add approved module manifest URLs here
    ]
    
    /// Built-in module factory functions
    private var builtInModuleFactories: [String: () -> any MusicModule] = [:]
    
    // MARK: - Initialization
    
    public init(
        securityManager: SecurityManager = SecurityManager.shared,
        networkLogger: NetworkLogger = NetworkLogger.shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.securityManager = securityManager
        self.networkLogger = networkLogger
        self.userDefaults = userDefaults
        
        registerBuiltInModules()
    }
    
    // MARK: - Module Registration
    
    /// Register built-in modules
    private func registerBuiltInModules() {
        // Register I'm Miserable module (enabled by default)
        builtInModuleFactories["im-miserable"] = {
            ImMiserableModule()
        }
        
        // Add more built-in modules here as needed
    }
    
    /// Load all registered modules
    public func loadModules() async {
        isLoading = true
        error = nil
        
            // Load built-in modules
            for (id, factory) in builtInModuleFactories {
                let module = factory()
                modules[id] = module
                
                // Check if module should be enabled
                let isEnabled = userDefaults.bool(forKey: "module.enabled.\(id)")
                    || !userDefaults.bool(forKey: "module.configured.\(id)") // Default enabled for new modules
                
                if isEnabled {
                    await enableModule(id: id)
                }
                
                // Mark as configured
                userDefaults.set(true, forKey: "module.configured.\(id)")
            }
            
            // Load remote modules (if approved)
            await loadRemoteModules()
            
            // Load dynamic JS modules
            await loadDynamicModules()
        
        isLoading = false
    }
    
    // MARK: - Dynamic Modules
    
    /// Registers a new dynamic module from source code
    public func registerDynamicModule(code: String) async throws {
        // Attempt to create it first to validate
        let module = try JavaScriptModule(sourceCode: code)
        let id = await module.id
        
        // Save to persistent storage
        var savedModules = userDefaults.dictionary(forKey: "dynamic.modules") as? [String: String] ?? [:]
        savedModules[id] = code
        userDefaults.set(savedModules, forKey: "dynamic.modules")
        
        // Register in memory
        modules[id] = module
        await enableModule(id: id)
    }
    
    /// Deletes a dynamic module
    public func deleteDynamicModule(id: String) async {
        await disableModule(id: id)
        modules.removeValue(forKey: id)
        
        var savedModules = userDefaults.dictionary(forKey: "dynamic.modules") as? [String: String] ?? [:]
        savedModules.removeValue(forKey: id)
        userDefaults.set(savedModules, forKey: "dynamic.modules")
    }
    
    private func loadDynamicModules() async {
        let savedModules = userDefaults.dictionary(forKey: "dynamic.modules") as? [String: String] ?? [:]
        for (id, code) in savedModules {
            do {
                let module = try JavaScriptModule(sourceCode: code)
                modules[id] = module
                
                // Enable if it was enabled
                if userDefaults.bool(forKey: "module.enabled.\(id)") {
                    await enableModule(id: id)
                }
            } catch {
                print("Failed to load dynamic module \(id): \(error)")
            }
        }
    }
    
    /// Load remote module manifests
    private func loadRemoteModules() async {
        for manifestURL in approvedManifestURLs {
            do {
                let manifest = try await fetchManifest(from: manifestURL)
                
                // Verify signature
                guard try await securityManager.verifyModuleSignature(manifest.signature) else {
                    await networkLogger.logPolicyViolation(
                        moduleId: manifest.id,
                        reason: "Invalid module signature"
                    )
                    continue
                }
                
                // TODO: Download and instantiate remote modules
                // This requires additional security measures
                
            } catch {
                print("Failed to load manifest from \(manifestURL): \(error)")
            }
        }
    }
    
    /// Fetch a module manifest
    private func fetchManifest(from url: URL) async throws -> ModuleManifest {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ModuleError.networkError("Failed to fetch manifest")
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ModuleManifest.self, from: data)
    }
    
    // MARK: - Module Access
    
    /// Get a specific module by ID
    public func module(id: String) -> (any MusicModule)? {
        modules[id]
    }
    
    /// Get all enabled modules
    public func getEnabledModules() -> [any MusicModule] {
        enabledModules
    }
    
    /// Get the primary (first enabled) module
    public var primaryModule: (any MusicModule)? {
        enabledModules.first
    }
    
    // MARK: - Module Lifecycle
    
    /// Enable a module
    public func enableModule(id: String) async {
        guard let module = modules[id] else { return }
        
        // Verify module security
        if let signature = await module.signature {
            do {
                guard try await securityManager.verifyModuleSignature(signature) else {
                    error = ModuleError.securityViolation("Module signature verification failed")
                    return
                }
            } catch {
                self.error = error
                return
            }
        }
        
        // Add to enabled list if not already present
        var alreadyEnabled = false
        for existingModule in enabledModules {
            if await existingModule.id == id {
                alreadyEnabled = true
                break
            }
        }
        
        if !alreadyEnabled {
            enabledModules.append(module)
        }
        
        userDefaults.set(true, forKey: "module.enabled.\(id)")
    }
    
    /// Disable a module
    public func disableModule(id: String) async {
        var indicesToRemove: [Int] = []
        for (index, module) in enabledModules.enumerated() {
            if await module.id == id {
                indicesToRemove.append(index)
            }
        }
        for index in indicesToRemove.reversed() {
            enabledModules.remove(at: index)
        }
        userDefaults.set(false, forKey: "module.enabled.\(id)")
    }
    
    /// Toggle module enabled state
    public func toggleModule(id: String) async {
        var isCurrentlyEnabled = false
        for module in enabledModules {
            if await module.id == id {
                isCurrentlyEnabled = true
                break
            }
        }
        if isCurrentlyEnabled {
            await disableModule(id: id)
        } else {
            await enableModule(id: id)
        }
    }
    
    // MARK: - Authentication
    
    /// Check authentication status for a module
    public func isAuthenticated(moduleId: String) async -> Bool {
        guard let module = modules[moduleId] else { return false }
        return await module.isAuthenticated
    }
    
    /// Initiate authentication for a module
    public func authenticate(moduleId: String) async throws -> URL? {
        guard let module = modules[moduleId] else {
            throw ModuleError.moduleDisabled
        }
        return try await module.authenticate()
    }
    
    /// Handle authentication callback
    public func handleAuthCallback(moduleId: String, callbackURL: URL) async throws {
        guard let module = modules[moduleId] else {
            throw ModuleError.moduleDisabled
        }
        try await module.handleAuthCallback(callbackURL: callbackURL)
    }
    
    /// Sign out from a module
    public func signOut(moduleId: String) async {
        guard let module = modules[moduleId] else { return }
        await module.signOut()
    }
    
    // MARK: - Search Aggregation
    
    /// Search across all enabled modules
    public func searchAll(query: String, limit: Int = 25) async -> [String: SearchResults] {
        var results: [String: SearchResults] = [:]
        
        await withTaskGroup(of: (String, SearchResults?).self) { group in
            for module in enabledModules {
                group.addTask {
                    do {
                        let moduleId = await module.id
                        let searchResults = try await module.searchTracks(query: query, limit: limit)
                        return (moduleId, searchResults)
                    } catch {
                        let moduleId = await module.id
                        print("Search failed for module \(moduleId): \(error)")
                        return (moduleId, nil)
                    }
                }
            }
            
            for await (moduleId, searchResults) in group {
                if let searchResults = searchResults {
                    results[moduleId] = searchResults
                }
            }
        }
        
        return results
    }
    
    /// Search using a specific module
    public func search(
        moduleId: String,
        query: String,
        limit: Int = 25
    ) async throws -> SearchResults {
        guard let module = modules[moduleId] else {
            throw ModuleError.moduleDisabled
        }
        return try await module.searchTracks(query: query, limit: limit)
    }
    
    // MARK: - Stream Resolution
    
    /// Get stream info for a track
    public func getStream(
        moduleId: String,
        trackId: String,
        quality: AudioQuality = .lossless
    ) async throws -> StreamInfo {
        guard let module = modules[moduleId] else {
            throw ModuleError.moduleDisabled
        }
        
        // Verify module is enabled
        var isEnabled = false
        for enabledModule in enabledModules {
            if await enabledModule.id == moduleId {
                isEnabled = true
                break
            }
        }
        guard isEnabled else {
            throw ModuleError.moduleDisabled
        }
        
        return try await module.getTrackStream(trackId: trackId, preferredQuality: quality)
    }
    
    // MARK: - Module Info
    
    /// Get module info for display
    public func getModuleInfo(id: String) async -> ModuleInfo? {
        guard let module = modules[id] else { return nil }
        
        var isEnabled = false
        for enabledModule in enabledModules {
            if await enabledModule.id == id {
                isEnabled = true
                break
            }
        }
        
        return ModuleInfo(
            id: await module.id,
            name: await module.name,
            version: await module.version,
            description: await module.description,
            labels: await module.labels,
            iconURL: await module.iconURL,
            isEnabled: isEnabled,
            requiresAuth: await module.requiresAuth,
            isAuthenticated: await module.isAuthenticated,
            allowedDomains: await module.allowedDomains
        )
    }
    
    /// Get all module infos
    public func getAllModuleInfos() async -> [ModuleInfo] {
        var infos: [ModuleInfo] = []
        for (id, _) in modules {
            if let info = await getModuleInfo(id: id) {
                infos.append(info)
            }
        }
        return infos
    }
}

// MARK: - Module Info

/// Displayable module information
public struct ModuleInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let labels: [String]
    public let iconURL: URL?
    public let isEnabled: Bool
    public let requiresAuth: Bool
    public let isAuthenticated: Bool
    public let allowedDomains: [String]
}

// MARK: - Module Registry Environment Key

private struct ModuleRegistryKey: EnvironmentKey {
    @MainActor
    static let defaultValue: ModuleRegistry = ModuleRegistry()
}

extension EnvironmentValues {
    public var moduleRegistry: ModuleRegistry {
        get { self[ModuleRegistryKey.self] }
        set { self[ModuleRegistryKey.self] = newValue }
    }
}
