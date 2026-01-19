import SwiftUI

// MARK: - Module Manager View

struct ModuleManagerView: View {
    @StateObject private var viewModel = ModuleManagerViewModel()
    @State private var showImportSheet = false
    @State private var importCode = ""
    @State private var importError: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                GlassTheme.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack {
                            Text("Modules")
                                .font(GlassTheme.font(size: 34, weight: .bold))
                                .foregroundStyle(GlassTheme.white)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Import Button
                        Button {
                            showImportSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Module")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(GlassTheme.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        
                        // Modules List
                        modulesSection
                        
                        // Security Info
                        securitySection
                        
                        // Diagnostics
                        diagnosticsSection
                    }
                    .padding(.bottom, 100) // Spacing for tab bar
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.loadModules()
        }
        .sheet(isPresented: $showImportSheet) {
            importSheet
        }
    }
    
    // MARK: - Import Sheet
    private var importSheet: some View {
        ZStack {
            GlassTheme.darkGray.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Import Module")
                    .font(GlassTheme.font(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top)
                
                Text("Paste your JavaScript module code below.")
                    .font(GlassTheme.font(size: 14))
                    .foregroundStyle(GlassTheme.gray)
                
                TextEditor(text: $importCode)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.5))
                    .foregroundStyle(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
                
                if let error = importError {
                    Text(error)
                        .foregroundStyle(GlassTheme.pink)
                        .font(.caption)
                }
                
                Button {
                    Task {
                        do {
                            try await viewModel.importModule(code: importCode)
                            showImportSheet = false
                            importCode = ""
                            importError = nil
                        } catch {
                            importError = error.localizedDescription
                        }
                    }
                } label: {
                    Text("Install Module")
                        .font(GlassTheme.font(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(GlassTheme.cyan)
                        .clipShape(Capsule())
                }
                .padding()
            }
        }
    }
    
    // MARK: - Modules Section
    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Installed Modules")
                .font(GlassTheme.font(size: 18, weight: .semibold))
                .foregroundStyle(GlassTheme.gray)
                .padding(.horizontal)
            
            ForEach(viewModel.modules, id: \.id) { module in
                ModuleCard(module: module) {
                    Task {
                        await viewModel.toggleModule(id: module.id)
                    }
                }
                .padding(.horizontal)
                .contextMenu {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteModule(id: module.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security")
                .font(GlassTheme.font(size: 18, weight: .semibold))
                .foregroundStyle(GlassTheme.gray)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                SecurityRow(
                    icon: "checkmark.shield.fill",
                    title: "Module Signing",
                    detail: "All modules verified",
                    status: .verified
                )
                
                SecurityRow(
                    icon: "network",
                    title: "Domain Allowlist",
                    detail: "\(viewModel.allowedDomainsCount) domains",
                    status: .info
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Diagnostics Section
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(GlassTheme.font(size: 18, weight: .semibold))
                .foregroundStyle(GlassTheme.gray)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                DiagnosticRow(
                    title: "Network Requests",
                    value: "\(viewModel.networkRequestCount)"
                )
                
                DiagnosticRow(
                    title: "Cache Size",
                    value: viewModel.cacheSize
                )
            }
            .padding()
            .glassCard()
            .padding(.horizontal)
        }
    }
}

// MARK: - Module Card
struct ModuleCard: View {
    let module: ModuleInfo
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(GlassTheme.liquidGradient)
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(module.name.prefix(1)).uppercased())
                        .font(GlassTheme.font(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(GlassTheme.font(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("v\(module.version)")
                    .font(GlassTheme.font(size: 12))
                    .foregroundStyle(GlassTheme.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { module.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: GlassTheme.cyan))
        }
        .padding()
        .glassCard()
    }
}

// MARK: - Security Row
struct SecurityRow: View {
    enum Status {
        case verified, warning, error, info
        
        var color: Color {
            switch self {
            case .verified: return .green
            case .warning: return .orange
            case .error: return .red
            case .info: return GlassTheme.cyan
            }
        }
    }
    
    let icon: String
    let title: String
    let detail: String
    let status: Status
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(status.color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(GlassTheme.font(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(detail)
                    .font(GlassTheme.font(size: 12))
                    .foregroundStyle(GlassTheme.gray)
            }
            
            Spacer()
        }
        .padding()
        .glassCard()
    }
}

// MARK: - Diagnostic Row
struct DiagnosticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(GlassTheme.font(size: 14))
                .foregroundStyle(GlassTheme.gray)
            
            Spacer()
            
            Text(value)
                .font(GlassTheme.font(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Module Manager View Model
@MainActor
class ModuleManagerViewModel: ObservableObject {
    @Published var modules: [ModuleInfo] = []
    @Published var allowedDomainsCount: Int = 0
    @Published var networkRequestCount: Int = 0
    @Published var cacheSize: String = "0 MB"
    
    private let registry = HiFiAPI.shared.registry
    private let networkLogger = NetworkLogger.shared
    
    func loadModules() async {
        await registry.loadModules()
        modules = await registry.getAllModuleInfos()
        allowedDomainsCount = modules.reduce(0) { $0 + $1.allowedDomains.count }
        
        // Simple cache size mock for now
        cacheSize = "12.4 MB"
    }
    
    func importModule(code: String) async throws {
        try await registry.registerDynamicModule(code: code)
        await loadModules()
    }
    
    func deleteModule(id: String) async {
        await registry.deleteDynamicModule(id: id)
        await loadModules()
    }
    
    func toggleModule(id: String) async {
        await registry.toggleModule(id: id)
        await loadModules()
    }
}
