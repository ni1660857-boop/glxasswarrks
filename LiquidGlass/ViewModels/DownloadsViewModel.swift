import Foundation

// MARK: - Downloads View Model

@MainActor

class DownloadsManager: ObservableObject {
    static let shared = DownloadsManager()
    
    @Published var downloads: [DownloadItem] = []
    @Published var activeDownloads: [DownloadItem] = []
    @Published var completedDownloads: [DownloadItem] = []
    @Published var storageUsed: Int64 = 0
    @Published var storageLimit: Int64 = 10 * 1024 * 1024 * 1024 // 10GB default
    
    private let fileManager = FileManager.default
    private let downloadsDirectory: URL
    private let storageKey = "downloads"
    
    var storageProgress: Double {
        guard storageLimit > 0 else { return 0 }
        return min(1.0, Double(storageUsed) / Double(storageLimit))
    }
    
    var formattedStorageUsed: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let used = formatter.string(fromByteCount: storageUsed)
        let limit = formatter.string(fromByteCount: storageLimit)
        return "\(used) / \(limit)"
    }
    
    init() {
        // Setup downloads directory
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        downloadsDirectory = paths[0].appendingPathComponent("Downloads")
        
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        loadDownloads()
        calculateStorageUsed()
    }
    
    // MARK: - Loading
    
    func loadDownloads() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            downloads = items
            updateFilteredLists()
        }
    }
    
    private func saveDownloads() {
        if let data = try? JSONEncoder().encode(downloads) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func updateFilteredLists() {
        activeDownloads = downloads.filter {
            $0.status == .downloading || $0.status == .pending || $0.status == .paused
        }
        completedDownloads = downloads.filter { $0.status == .completed }
    }
    
    // MARK: - Download Management
    
    func startDownload(_ track: Track, quality: AudioQuality = .lossless) async {
        let item = DownloadItem(track: track, quality: quality)
        downloads.append(item)
        updateFilteredLists()
        saveDownloads()
        
        // TODO: Implement actual download logic
        // This would involve:
        // 1. Getting download URL from HiFi API
        // 2. Starting URLSessionDownloadTask
        // 3. Updating progress via delegate
        // 4. Saving file to downloads directory
        
        // Simulate download for now
        await simulateDownload(item)
    }
    
    private func simulateDownload(_ item: DownloadItem) async {
        guard let index = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        
        downloads[index].status = .downloading
        updateFilteredLists()
        
        // Simulate progress
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }
            downloads[idx].progress = progress
            updateFilteredLists()
        }
        
        // Mark complete
        if let idx = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[idx].status = .completed
            downloads[idx].completedAt = Date()
            updateFilteredLists()
            saveDownloads()
            calculateStorageUsed()
        }
    }
    
    func pauseDownload(_ item: DownloadItem) {
        guard let index = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        downloads[index].status = .paused
        updateFilteredLists()
        saveDownloads()
    }
    
    func resumeDownload(_ item: DownloadItem) async {
        guard let index = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        
        let currentProgress = downloads[index].progress
        downloads[index].status = .downloading
        updateFilteredLists()
        
        // Continue simulation
        for progress in stride(from: currentProgress, through: 1.0, by: 0.1) {
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }
            downloads[idx].progress = progress
            updateFilteredLists()
        }
        
        if let idx = downloads.firstIndex(where: { $0.id == item.id }) {
            downloads[idx].status = .completed
            downloads[idx].completedAt = Date()
            updateFilteredLists()
            saveDownloads()
        }
    }
    
    func cancelDownload(_ item: DownloadItem) {
        guard let index = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        downloads[index].status = .cancelled
        updateFilteredLists()
        saveDownloads()
    }
    
    func deleteDownload(_ item: DownloadItem) {
        // Remove file if exists
        if let localURL = item.localURL {
            try? fileManager.removeItem(at: localURL)
        }
        
        downloads.removeAll { $0.id == item.id }
        updateFilteredLists()
        saveDownloads()
        calculateStorageUsed()
    }
    
    func retryDownload(_ item: DownloadItem) async {
        guard let index = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        downloads[index].status = .pending
        downloads[index].progress = 0
        downloads[index].error = nil
        updateFilteredLists()
        
        let itemToRetry = downloads[index]
        await simulateDownload(itemToRetry)
    }
    
    // MARK: - Storage
    
    private func calculateStorageUsed() {
        var total: Int64 = 0
        
        if let contents = try? fileManager.contentsOfDirectory(
            at: downloadsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for url in contents {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        
        storageUsed = total
    }
    
    func clearAllDownloads() {
        // Remove all files
        try? fileManager.removeItem(at: downloadsDirectory)
        try? fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        downloads.removeAll()
        updateFilteredLists()
        saveDownloads()
        calculateStorageUsed()
    }
}
