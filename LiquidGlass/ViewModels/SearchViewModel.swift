import Foundation

// MARK: - Search View Model

@MainActor
class SearchViewModelImpl: ObservableObject {
    @Published var query = ""
    @Published var results = SearchResults.empty
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchHistory: [String] = []
    
    private let hifiAPI = HiFiAPI.shared
    private var searchTask: Task<Void, Never>?
    private let maxHistoryItems = 10
    
    init() {
        loadSearchHistory()
    }
    
    // MARK: - Search
    
    func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = .empty
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            results = try await hifiAPI.search(query: query.trimmingCharacters(in: .whitespaces))
            addToHistory(query)
        } catch {
            self.error = error
            results = .empty
        }
        
        isLoading = false
    }
    
    func debounceSearch() async {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            if !Task.isCancelled {
                await search()
            }
        }
    }
    
    func clearSearch() {
        query = ""
        results = .empty
        searchTask?.cancel()
    }
    
    // MARK: - History
    
    private func addToHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Remove existing occurrence
        searchHistory.removeAll { $0.lowercased() == trimmed.lowercased() }
        
        // Add to front
        searchHistory.insert(trimmed, at: 0)
        
        // Limit size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    
    func clearHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: "searchHistory") ?? []
    }
    
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "searchHistory")
    }
}
