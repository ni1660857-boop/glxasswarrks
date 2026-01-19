import SwiftUI

// MARK: - Module Manager View

struct ModuleManagerView: View {
    @StateObject private var viewModel = ModuleManagerViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfacePrimary.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Modules List
                        modulesSection
                        
                        // Security Info
                        securitySection
                        
                        // Diagnostics
                        diagnosticsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Modules")
        }
        .task {
            await viewModel.loadModules()
        }
    }
    
    // MARK: - Modules Section
    private var modulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Installed Modules")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            ForEach(viewModel.modules, id: \.id) { module in
                ModuleCard(module: module) {
                    Task {
                        await viewModel.toggleModule(id: module.id)
                    }
                }
            }
        }
    }
    
    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
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
                
                SecurityRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Policy Violations",
                    detail: "\(viewModel.violationsCount) violations",
                    status: viewModel.violationsCount > 0 ? .warning : .verified
                )
            }
        }
    }
    
    // MARK: - Diagnostics Section
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            
            VStack(spacing: 12) {
                DiagnosticRow(
                    title: "Network Requests",
                    value: "\(viewModel.networkRequestCount)"
                )
                
                DiagnosticRow(
                    title: "Cache Size",
                    value: viewModel.cacheSize
                )
                
                DiagnosticRow(
                    title: "Avg Response Time",
                    value: "\(viewModel.avgResponseTime)ms"
                )
            }
            .padding()
            .glassCard(cornerRadius: 16)
            
            // Clear logs button
            Button {
                Task { await viewModel.clearLogs() }
            } label: {
                HStack {
                    Spacer()
                    Text("Clear Logs")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding()
                .glassCard(cornerRadius: 12)
            }
            .foregroundStyle(Color.textSecondary)
        }
    }
}

// MARK: - Module Card
struct ModuleCard: View {
    let module: ModuleInfo
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentGlow, Color.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(module.name.prefix(2)).uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    
                    Text("v\(module.version)")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { module.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color.accentGlow))
            }
            
            Text(module.description)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
            
            // Labels
            if !module.labels.isEmpty {
                HStack(spacing: 8) {
                    ForEach(module.labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentGlow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.accentGlow.opacity(0.15))
                            )
                    }
                }
            }
            
            // Auth status
            if module.requiresAuth {
                HStack(spacing: 6) {
                    Image(systemName: module.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(module.isAuthenticated ? .green : .red)
                    
                    Text(module.isAuthenticated ? "Authenticated" : "Not authenticated")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            
            // Allowed domains
            Text("Domains: \(module.allowedDomains.joined(separator: ", "))")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
        }
        .padding()
        .glassCard(cornerRadius: 16)
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
            case .info: return Color.accentGlow
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Diagnostic Row
struct DiagnosticRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Module Manager View Model
@MainActor
class ModuleManagerViewModel: ObservableObject {
    @Published var modules: [ModuleInfo] = []
    @Published var violationsCount: Int = 0
    @Published var allowedDomainsCount: Int = 0
    @Published var networkRequestCount: Int = 0
    @Published var cacheSize: String = "0 MB"
    @Published var avgResponseTime: Int = 0
    
    private let registry = HiFiAPI.shared.registry
    private let securityManager = SecurityManager.shared
    private let networkLogger = NetworkLogger.shared
    
    func loadModules() async {
        await registry.loadModules()
        modules = await registry.getAllModuleInfos()
        
        // Count allowed domains
        allowedDomainsCount = modules.reduce(0) { $0 + $1.allowedDomains.count }
        
        // Get violations
        violationsCount = await securityManager.getViolations().count
        
        // Get network stats
        let logs = await networkLogger.getLogs(limit: 1000)
        networkRequestCount = logs.count
        
        let durations = logs.compactMap { $0.duration }
        if !durations.isEmpty {
            avgResponseTime = Int((durations.reduce(0, +) / Double(durations.count)) * 1000)
        }
    }
    
    func toggleModule(id: String) async {
        await registry.toggleModule(id: id)
        await loadModules()
    }
    
    func clearLogs() async {
        await networkLogger.clear()
        networkRequestCount = 0
    }
}
