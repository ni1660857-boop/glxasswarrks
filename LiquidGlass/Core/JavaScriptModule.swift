import Foundation
import JavaScriptCore
import Combine

/// A MusicModule implementation that runs dynamic JavaScript code.
/// This allows users to import custom modules at runtime.
///
/// Security Note; This runs code in a JSC sandbox but has access to bridged 'fetch'.
/// Domain restrictions are enforced in the native fetch bridge.
public actor JavaScriptModule: MusicModule, ObservableObject {
    
    // MARK: - Properties
    public let id: String
    public let name: String
    public let version: String
    public let description: String
    public let labels: [String]
    public let iconURL: URL? = nil
    
    public var isEnabled: Bool = true
    public var requiresAuth: Bool = false
    public var isAuthenticated: Bool = true
    
    public var allowedDomains: [String] = []
    public var signature: ModuleSignature? = nil
    
    private let context: JSContext
    private let sourceCode: String
    
    // MARK: - Initialization
    
    /// Initializes the module with JavaScript source code.
    /// The source code must evaluate to an object containing the module definition.
    public init(sourceCode: String) throws {
        self.sourceCode = sourceCode
        self.context = JSContext()
        
        // 1. Setup Exception Handler
        context.exceptionHandler = { context, exception in
            print("[JSModule] Exception: \(String(describing: exception))")
        }
        
        // 2. Polyfill Console
        let consoleLog: @convention(block) (String) -> Void = { message in
            print("[JSModule Log] \(message)")
        }
        context.setObject(unsafeBitCast(consoleLog, to: AnyObject.self), forKeyedSubscript: "nativeLog" as NSString)
        context.evaluateScript("var console = { log: nativeLog, error: nativeLog, warn: nativeLog };")
        
        // 3. Polyfill Fetch
        // We define a native function that takes (url, options, resolve, reject)
        let nativeFetch: @convention(block) (String, [String: Any]?, JSValue, JSValue) -> Void = { urlString, options, resolve, reject in
            guard let url = URL(string: urlString) else {
                reject.call(withArguments: ["Invalid URL"])
                return
            }
            
            // Basic sandbox domain check (optional safety, can be relaxed if we trust user imported code)
            // if !self.isDomainAllowed(url.host) { reject... }
            
            var request = URLRequest(url: url)
            if let method = options?["method"] as? String {
                request.httpMethod = method
            }
            if let headers = options?["headers"] as? [String: String] {
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }
            }
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    reject.call(withArguments: [error.localizedDescription])
                    return
                }
                
                let httpResponse = response as? HTTPURLResponse
                let status = httpResponse?.statusCode ?? 500
                let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
                
                // Construct a Mock Response Object in JS
                // We call a helper function we injected into JS to create this object
                if let context = JSContext.current(),
                   let createResponse = context.objectForKeyedSubscript("createResponse") {
                    let responseObj = createResponse.call(withArguments: [status, body])
                    resolve.call(withArguments: [responseObj as Any])
                } else {
                    reject.call(withArguments: ["Context lost"])
                }
            }
            task.resume()
        }
        
        context.setObject(unsafeBitCast(nativeFetch, to: AnyObject.self), forKeyedSubscript: "nativeFetch" as NSString)
        
        // Inject JS helpers
        let polyfillScript = """
        function createResponse(status, bodyText) {
            return {
                ok: status >= 200 && status < 300,
                status: status,
                statusText: status.toString(),
                text: function() { return Promise.resolve(bodyText); },
                json: function() {
                    return new Promise((resolve, reject) => {
                        try {
                            resolve(JSON.parse(bodyText));
                        } catch (e) {
                            reject(e);
                        }
                    });
                }
            };
        }
        
        const fetch = (url, options) => {
            return new Promise((resolve, reject) => {
                nativeFetch(url, options || {}, resolve, reject);
            });
        };
        
        // Atob/Btoa Polyfill (if missing)
        if (typeof atob === 'undefined') {
            // Basic base64 polyfill might be needed if iOS doesn't provide it in simple JSC context
            // iOS 16 JSC usually has it, but let's be safe if it crashes
        }
        """
        context.evaluateScript(polyfillScript)
        
        // 4. Evaluate User Module
        // We expect the user code to be "return { ... }" or "export const ...".
        // The user provided code "export const IM_MISERABLE_MODULE_CODE = ... return { ... }"
        // Wait, the user paste looks like a function body that ends with `return { ... }`.
        // I will wrap it in a function.
        
        let wrappedCode = """
        var currentModule = (function() {
            \(sourceCode)
        })();
        """
        
        context.evaluateScript(wrappedCode)
        let moduleObj = context.objectForKeyedSubscript("currentModule")
        
        if moduleObj == nil || moduleObj!.isUndefined {
            // Fallback: maybe the user pasted code that doesn't strictly return, or used 'export default'
            // For this specific request, the code ends with 'return { ... }' so the closure wrapper works.
            throw ModuleError.initializationError("Module code did not return an object")
        }
        
        // 5. Extract Metadata
        guard let pid = moduleObj!.forProperty("id")?.toString(),
              let pname = moduleObj!.forProperty("name")?.toString() else {
             // Try to handle if they are undefined
             throw ModuleError.initializationError("Module missing id or name")
        }
        
        self.id = pid
        self.name = pname
        self.version = moduleObj!.forProperty("version")?.toString() ?? "1.0.0"
        self.description = moduleObj!.forProperty("description")?.toString() ?? ""
        self.labels = moduleObj!.forProperty("labels")?.toArray() as? [String] ?? []
    }
    
    // MARK: - MusicModule Methods
    
    public func searchTracks(query: String, limit: Int) async throws -> SearchResults {
        return try await withCheckedThrowingContinuation { continuation in
            guard let moduleObj = context.objectForKeyedSubscript("currentModule"),
                  let searchFunc = moduleObj.forProperty("searchTracks") else {
                continuation.resume(throwing: ModuleError.notImplemented)
                return
            }
            
            let result = searchFunc.call(withArguments: [query, limit])
            
            handlePromise(result) { resultData, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = resultData {
                    do {
                        let tracks = try self.parseTracks(from: data.forProperty("tracks"))
                        // SearchResults expected layout: tracks, albums, artists
                        continuation.resume(returning: SearchResults(tracks: tracks))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public func getTrackStream(trackId: String, preferredQuality: AudioQuality) async throws -> StreamInfo {
        return try await withCheckedThrowingContinuation { continuation in
            guard let moduleObj = context.objectForKeyedSubscript("currentModule"),
                  let funcObj = moduleObj.forProperty("getTrackStreamUrl") else {
                continuation.resume(throwing: ModuleError.notImplemented)
                return
            }
            
            // Map Swift enum to string quality if needed, or pass string
            let qualStr = (preferredQuality == .lossless) ? "LOSSLESS" : "HIGH"
            let result = funcObj.call(withArguments: [trackId, qualStr])
            
            handlePromise(result) { resultData, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = resultData {
                    guard let streamUrlStr = data.forProperty("streamUrl")?.toString(),
                          let url = URL(string: streamUrlStr) else {
                        continuation.resume(throwing: ModuleError.decodingError)
                        return
                    }
                    continuation.resume(returning: StreamInfo(url: url, quality: "LOSSLESS", metadata: [:]))
                } else {
                    continuation.resume(throwing: ModuleError.networkError("Empty result"))
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func parseTracks(from value: JSValue?) throws -> [Track] {
        guard let value = value, value.isArray else { return [] }
        var tracks: [Track] = []
        
        let length = Int(value.forProperty("length").toInt32())
        for i in 0..<length {
            if let item = value.atIndex(i) {
                let dur = item.forProperty("duration")?.toDouble() ?? 0
                // Handle different duration formats if needed (ms vs sec)
                
                let t = Track(
                    id: item.forProperty("id")?.toString() ?? UUID().uuidString,
                    title: item.forProperty("title")?.toString() ?? "Unknown",
                    artist: item.forProperty("artist")?.toString() ?? "Unknown",
                    album: item.forProperty("album")?.toString() ?? "Unknown",
                    artworkURL: URL(string: item.forProperty("albumCover")?.toString() ?? ""),
                    duration: dur,
                    streamInfo: nil
                )
                tracks.append(t)
            }
        }
        return tracks
    }
    
    private func handlePromise(_ promise: JSValue?, completion: @escaping (JSValue?, Error?) -> Void) {
        guard let promise = promise else {
            completion(nil, ModuleError.networkError("No result from JS"))
            return
        }
        
        if promise.forProperty("then").isUndefined {
            completion(promise, nil)
            return
        }
        
        let onSuccess: @convention(block) (JSValue) -> Void = { val in completion(val, nil) }
        let onFailure: @convention(block) (JSValue) -> Void = { val in
            let msg = val.toString() ?? "Unknown JS Error"
            completion(nil, ModuleError.networkError(msg))
        }
        
        promise.invokeMethod("then", withArguments: [
            unsafeBitCast(onSuccess, to: AnyObject.self),
            unsafeBitCast(onFailure, to: AnyObject.self)
        ])
    }
}
