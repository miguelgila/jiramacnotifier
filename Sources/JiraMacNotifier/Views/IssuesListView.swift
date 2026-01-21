import SwiftUI

struct IssuesListView: View {
    @ObservedObject var configManager: ConfigurationManager
    @ObservedObject var pollingService: PollingService

    @State private var issues: [IssueDisplayItem] = []
    @State private var selectedIssueIds: Set<String> = []
    @State private var showingUnreadOnly = false
    @State private var searchText = ""

    private let databaseManager = DatabaseManager()

    var filteredIssues: [IssueDisplayItem] {
        var result = issues

        if showingUnreadOnly {
            result = result.filter { !$0.isRead }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.issueKey.localizedCaseInsensitiveContains(searchText) ||
                $0.summary.localizedCaseInsensitiveContains(searchText) ||
                $0.status.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var unreadCount: Int {
        issues.filter { !$0.isRead }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notifications")
                    .font(.title2)
                    .bold()

                if unreadCount > 0 {
                    Text("\(unreadCount) unread")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }

                Spacer()

                Toggle("Unread only", isOn: $showingUnreadOnly)
                    .toggleStyle(.switch)

                Button(action: refreshIssues) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search issues...", text: $searchText)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)

            Divider()

            // Selection toolbar
            if !selectedIssueIds.isEmpty {
                HStack {
                    Button(action: selectAll) {
                        Label("Select All", systemImage: "checkmark.circle")
                    }

                    Button(action: deselectAll) {
                        Label("Deselect All", systemImage: "circle")
                    }

                    Spacer()

                    Text("\(selectedIssueIds.count) selected")
                        .foregroundColor(.secondary)

                    Button(action: markSelectedAsRead) {
                        Label("Mark as Read", systemImage: "envelope.open")
                    }
                    .disabled(selectedIssueIds.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()
            }

            // Issues list
            if filteredIssues.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: issues.isEmpty ? "tray" : "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(issues.isEmpty ? "No notifications yet" : "No matching notifications")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    if !issues.isEmpty {
                        Text("Try adjusting your filters or search")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredIssues) { issue in
                            IssueRow(
                                issue: issue,
                                isSelected: selectedIssueIds.contains(issue.id),
                                onToggleSelect: { toggleSelection(issue.id) },
                                onOpen: { openInJira(issue) },
                                onMarkAsRead: { markAsRead(issue) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .onAppear {
            refreshIssues()
        }
        .onChange(of: pollingService.pollStatuses) { _ in
            refreshIssues()
        }
    }

    private func refreshIssues() {
        do {
            let issueStates = try databaseManager.getAllIssueStates()

            // Build display items with full context
            issues = issueStates.compactMap { state in
                guard let instance = configManager.instances.first(where: { $0.id == state.instanceId }),
                      let filter = instance.filters.first(where: { $0.id == state.filterId }) else {
                    return nil
                }

                let isNew = state.lastNotifiedAt == nil

                return IssueDisplayItem(
                    id: "\(state.issueId)-\(state.instanceId)-\(state.filterId)",
                    issueKey: state.issueKey,
                    summary: state.summary,
                    status: state.status,
                    priority: nil,
                    assignee: nil,
                    updatedAt: state.updatedAt,
                    instanceId: state.instanceId,
                    instanceName: instance.name,
                    instanceUrl: instance.url,
                    filterId: state.filterId,
                    filterName: filter.name,
                    isRead: state.isRead,
                    isNew: isNew
                )
            }
        } catch {
            print("Failed to load issues: \(error)")
        }
    }

    private func toggleSelection(_ issueId: String) {
        if selectedIssueIds.contains(issueId) {
            selectedIssueIds.remove(issueId)
        } else {
            selectedIssueIds.insert(issueId)
        }
    }

    private func selectAll() {
        selectedIssueIds = Set(filteredIssues.map { $0.id })
    }

    private func deselectAll() {
        selectedIssueIds.removeAll()
    }

    private func markSelectedAsRead() {
        do {
            let issueIds = selectedIssueIds.compactMap { id in
                issues.first(where: { $0.id == id })?.issueKey
            }
            try databaseManager.markMultipleAsRead(issueIds: issueIds)
            selectedIssueIds.removeAll()
            refreshIssues()
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    private func markAsRead(_ issue: IssueDisplayItem) {
        do {
            try databaseManager.markAsRead(
                issueId: issue.issueKey,
                instanceId: issue.instanceId,
                filterId: issue.filterId
            )
            refreshIssues()
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    private func openInJira(_ issue: IssueDisplayItem) {
        if let url = URL(string: issue.jiraUrl) {
            NSWorkspace.shared.open(url)

            // Mark as read when opened
            markAsRead(issue)
        }
    }
}

struct IssueRow: View {
    let issue: IssueDisplayItem
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onOpen: () -> Void
    let onMarkAsRead: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            // Read/unread indicator
            Circle()
                .fill(issue.isRead ? Color.clear : Color.orange)
                .frame(width: 8, height: 8)

            // Issue content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(issue.issueKey)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.accentColor)

                    if issue.isNew {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }

                    Text(issue.status)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(for: issue.status))
                        .cornerRadius(4)

                    Spacer()

                    Text(timeAgo(issue.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(issue.summary)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundColor(issue.isRead ? .secondary : .primary)

                HStack(spacing: 8) {
                    Label(issue.instanceName, systemImage: "server.rack")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Label(issue.filterName, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons
            VStack(spacing: 8) {
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Open in Jira")

                if !issue.isRead {
                    Button(action: onMarkAsRead) {
                        Image(systemName: "envelope.open")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Mark as read")
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    private func statusColor(for status: String) -> Color {
        let lowercased = status.lowercased()
        if lowercased.contains("done") || lowercased.contains("resolved") || lowercased.contains("closed") {
            return .green
        } else if lowercased.contains("progress") || lowercased.contains("review") {
            return .blue
        } else if lowercased.contains("blocked") || lowercased.contains("waiting") {
            return .red
        } else {
            return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }
}
