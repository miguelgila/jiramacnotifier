# Jira Mac Notifier - Development Documentation

## Project Overview

Jira Mac Notifier is a native macOS application built with Swift and SwiftUI that provides desktop notifications for Jira issue updates. It monitors multiple Jira instances using custom JQL filters and alerts users when issues are updated.

### Key Design Principles

1. **Lightweight**: Small memory footprint, minimal CPU usage
2. **Secure**: API tokens stored in macOS Keychain, never in plain text
3. **Native**: Uses macOS APIs for notifications, persistence, and UI
4. **Fast**: Efficient polling with SQLite-based change detection
5. **Standalone**: Single .app bundle with no external dependencies

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                          │
│  (ContentView, InstanceDetailView, AddInstanceView)        │
└─────────────────────────┬───────────────────────────────────┘
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                  ConfigurationManager                       │
│              (Observable, manages instances)                 │
└─────────────────────────┬───────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│  Keychain    │  │   Polling   │  │  Database   │
│   Manager    │  │   Service   │  │   Manager   │
└──────────────┘  └──────┬──────┘  └─────────────┘
                         │
                  ┌──────▼──────┐
                  │ JiraClient  │
                  └──────┬──────┘
                         │
                  ┌──────▼──────┐
                  │ Notification│
                  │   Service   │
                  └─────────────┘
```

### Core Components

#### 1. Models (`Models.swift`)

Defines the data structures used throughout the app:

- **`JiraInstance`**: Represents a Jira server connection
  - Contains URL, username, poll interval, and filters
  - Conforms to `Codable` for JSON persistence
  - Uses UUID for unique identification

- **`JiraFilter`**: Represents a JQL query filter
  - Contains name, JQL query string
  - Can be enabled/disabled independently
  - Associated with a parent instance

- **`JiraIssue`**: Represents a Jira issue from the API
  - Maps to Jira REST API response structure
  - Contains fields: summary, status, updated time, etc.

- **`IssueState`**: Tracks issue state in the database
  - Records when issue was last seen and notified
  - Used for change detection

#### 2. KeychainManager (`KeychainManager.swift`)

Secure storage for Jira API tokens using macOS Keychain.

**Key Features:**
- Uses `Security.framework` with `kSecClassGenericPassword`
- Tokens stored per-instance using UUID as account identifier
- Automatic encryption and access control by macOS
- Service name: `com.jiramacnotifier.tokens`

**API:**
```swift
func saveToken(_ token: String, for instanceId: String) throws
func getToken(for instanceId: String) throws -> String
func deleteToken(for instanceId: String) throws
func hasToken(for instanceId: String) -> Bool
```

**Security:**
- Tokens never written to disk in plain text
- Only accessible by the app that created them
- Survives app uninstall (intentional for security)

#### 3. JiraClient (`JiraClient.swift`)

Handles all communication with Jira REST API.

**Key Features:**
- Async/await based networking
- Bearer token authentication
- Proper error handling with custom error types
- Efficient pagination (max 100 results per query)

**API:**
```swift
func searchIssues(instance: JiraInstance, jql: String) async throws -> [JiraIssue]
func testConnection(instance: JiraInstance) async throws -> Bool
```

**Endpoints Used:**
- `/rest/api/2/search` - JQL search
- `/rest/api/2/myself` - Connection test

#### 4. DatabaseManager (`DatabaseManager.swift`)

SQLite-based persistence for tracking issue states.

**Schema:**
```sql
CREATE TABLE issue_states (
    issue_id TEXT,
    issue_key TEXT,
    instance_id TEXT,
    filter_id TEXT,
    summary TEXT,
    status TEXT,
    updated_at DATETIME,
    last_notified_at DATETIME,
    PRIMARY KEY (issue_id, instance_id, filter_id)
);
```

**Key Features:**
- Uses SQLite.swift library for type-safe queries
- Stores database in `~/Library/Application Support/JiraMacNotifier/`
- Tracks when each issue was last updated and notified
- Efficient indexes on instance_id and filter_id

**Change Detection:**
- Compares `updated_at` with `last_notified_at`
- Only notifies if issue changed since last notification
- Handles new issues (no previous state)

#### 5. ConfigurationManager (`ConfigurationManager.swift`)

Manages application configuration and instance lifecycle.

**Key Features:**
- SwiftUI `ObservableObject` for reactive UI
- JSON-based configuration persistence
- Coordinates with KeychainManager for tokens
- Auto-saves on changes

**Storage:**
- Configuration file: `~/Library/Application Support/JiraMacNotifier/config.json`
- Contains all instances and filters (except tokens)

#### 6. PollingService (`PollingService.swift`)

Background service that periodically checks for issue updates.

**Key Features:**
- Separate timer per instance (respects individual poll intervals)
- `@MainActor` for thread-safe UI updates
- Graceful error handling (doesn't crash on network errors)
- Immediate poll on start

**Flow:**
1. Schedule timers for each enabled instance
2. On timer fire, execute all enabled filters for that instance
3. For each returned issue:
   - Check if it exists in database
   - Compare update times
   - Send notification if changed
   - Update database with new state

#### 7. NotificationService (`NotificationService.swift`)

Manages macOS notification center integration.

**Key Features:**
- Requests notification permissions on first run
- Creates rich notifications with title, body, subtitle
- Supports notification actions (e.g., "Open in Browser")
- Stores metadata in notification userInfo

**Notification Format:**
- **Title**: `{Instance Name} - {Filter Name}`
- **Body**: `{Issue Key}: {Summary}`
- **Subtitle**: `Status: {Status}`

### User Interface

Built with SwiftUI for native macOS experience.

#### ContentView

Main application window with master-detail layout:
- **Sidebar**: List of Jira instances
- **Detail**: Instance configuration and filters
- **Toolbar**: Add instance, start/stop polling, poll now

#### InstanceDetailView

Shows detailed configuration for selected instance:
- Instance settings (name, URL, username, token)
- Poll interval configuration
- Connection testing
- Filter management (add, edit, delete, enable/disable)

#### AddInstanceView & AddFilterView

Modal sheets for adding new instances and filters:
- Form validation
- Inline error display
- Save/cancel actions

## Building and Testing

### Development Build

```bash
# Build debug version
swift build

# Run tests
swift test

# Run with coverage
swift test --enable-code-coverage
```

### Release Build

```bash
# Build optimized release
swift build -c release

# Create app bundle
./scripts/build-app.sh

# Install to Applications
cp -r JiraMacNotifier.app /Applications/
```

### Running Tests

The project includes comprehensive unit tests covering:

- **KeychainManagerTests**: Token storage and retrieval
- **DatabaseManagerTests**: SQLite operations and queries
- **ConfigurationManagerTests**: Instance management and persistence
- **ModelsTests**: Codable conformance and business logic
- **JiraClientTests**: API client initialization and error handling

**Coverage Target**: Minimum 70% code coverage enforced in CI

### CI/CD Pipeline

GitHub Actions workflow (`.github/workflows/ci.yml`):

1. **Test Job**:
   - Runs on macOS 13
   - Executes all tests with coverage
   - Generates LCOV coverage report
   - Enforces 70% minimum coverage
   - Uploads to Codecov

2. **Lint Job**:
   - Runs SwiftLint for code style
   - Configuration in `.swiftlint.yml`

3. **Build Job**:
   - Creates release build
   - Generates app bundle with Info.plist
   - Packages as ZIP artifact
   - Uploads for distribution

## Configuration Files

### Package.swift

Swift Package Manager manifest:
- Target platform: macOS 13+
- Dependencies: SQLite.swift 0.15.0+
- Defines executable and test targets

### .swiftlint.yml

SwiftLint configuration:
- Line length: 120 warning, 200 error
- Enforces Swift style guidelines
- Excludes build directories and tests

### Info.plist (generated)

macOS application metadata:
- Bundle identifier: `com.jiramacnotifier`
- Minimum OS: macOS 13.0
- High resolution capable
- Version: 1.0.0

## Data Flow

### Polling Cycle

```
Start Polling
     │
     ├─→ For Each Enabled Instance
     │        │
     │        ├─→ For Each Enabled Filter
     │        │        │
     │        │        ├─→ Execute JQL Query via JiraClient
     │        │        │        │
     │        │        │        └─→ Get List of Issues
     │        │        │
     │        │        └─→ For Each Issue
     │        │                 │
     │        │                 ├─→ Check DatabaseManager for Existing State
     │        │                 │
     │        │                 ├─→ Compare Update Times
     │        │                 │
     │        │                 ├─→ If Changed: Send Notification
     │        │                 │
     │        │                 └─→ Update Database
     │        │
     │        └─→ Schedule Next Poll (after interval)
     │
     └─→ Repeat
```

### Configuration Save Flow

```
User Makes Change
     │
     ├─→ Update View State
     │
     ├─→ ConfigurationManager.updateInstance()
     │        │
     │        ├─→ If Token Provided: KeychainManager.saveToken()
     │        │
     │        └─→ Save JSON to Disk
     │
     └─→ PollingService.restart()
              │
              └─→ Re-schedule Timers
```

## Security Considerations

### Token Storage

- **Storage**: macOS Keychain using Security.framework
- **Service**: `com.jiramacnotifier.tokens`
- **Account**: Instance UUID
- **Access**: App-specific, requires user authentication for access
- **Encryption**: Handled automatically by macOS

### API Communication

- **Protocol**: HTTPS only (enforced)
- **Authentication**: Bearer token in Authorization header
- **No Caching**: Tokens never cached in memory longer than needed
- **Error Handling**: Errors logged but tokens never exposed

### Data Privacy

- **Local Storage**: All data stored locally on user's Mac
- **No Telemetry**: No analytics or tracking
- **No Cloud**: No data sent to third parties
- **Issue Data**: Cached locally in SQLite for change detection only

## Performance Optimization

### Memory Management

- Timers use `[weak self]` to prevent retain cycles
- Database connections reused, not recreated
- Issue states only loaded when needed
- SwiftUI views use `@StateObject` and `@ObservedObject` appropriately

### Network Efficiency

- Pagination limits results to 100 per query
- Only requests fields that are actually used
- Connection pooling via shared URLSession
- Respects per-instance poll intervals (no unnecessary requests)

### Database Optimization

- Indexed columns: `instance_id`, `filter_id`
- Primary key on `(issue_id, instance_id, filter_id)`
- Upsert pattern for updates (INSERT OR REPLACE)
- Prepared statements via SQLite.swift

## Extending the Application

### Adding New Jira Fields

1. Update `JiraIssueFields` struct in `Models.swift`
2. Add field to JQL select in `JiraClient.searchIssues()`
3. Update `IssueState` if needed for change detection
4. Modify notification format in `NotificationService` if desired

### Supporting Jira Server (vs Cloud)

1. Add authentication method selection in UI
2. Implement Basic Auth in `JiraClient`
3. Update connection test for different API paths
4. Add API version detection

### Adding More Notification Actions

1. Define new `UNNotificationAction` in `NotificationService`
2. Add to `UNNotificationCategory`
3. Handle action in `AppDelegate.userNotificationCenter(_:didReceive:)`
4. Store necessary metadata in notification `userInfo`

## Troubleshooting

### Common Issues

**Issue**: Notifications not appearing
- **Cause**: Notification permissions not granted
- **Fix**: Check System Preferences → Notifications

**Issue**: "Token not found" error
- **Cause**: Keychain entry deleted or corrupted
- **Fix**: Re-enter token in instance settings

**Issue**: High CPU usage
- **Cause**: Polling interval too short or too many filters
- **Fix**: Increase poll interval, reduce number of active filters

**Issue**: Database locked error
- **Cause**: Multiple operations accessing database simultaneously
- **Fix**: Already handled with proper locking in SQLite.swift

### Debug Mode

To enable debug logging, modify source files to add:

```swift
// In PollingService.swift
print("Polling instance: \(instance.name)")
print("Found \(issues.count) issues")

// In JiraClient.swift
print("Request URL: \(url)")
print("Response status: \(httpResponse.statusCode)")
```

## Future Enhancements

Potential improvements for future versions:

1. **Menu Bar App**: Run as menu bar icon instead of dock icon
2. **Smart Notifications**: Group similar notifications
3. **Notification History**: View past notifications in app
4. **Quick Actions**: Transition issue status from notification
5. **Dashboard View**: Summary of all monitored issues
6. **Export/Import**: Share configurations between machines
7. **Dark Mode Icons**: Custom app icon variants
8. **Sparkle Integration**: Automatic update checking
9. **Advanced Filtering**: Client-side filter refinement
10. **Statistics**: Track notification patterns and issue trends

## Contributing

When contributing to this project:

1. Run tests before submitting: `swift test`
2. Ensure code coverage stays above 70%
3. Follow SwiftLint rules: `swiftlint lint`
4. Update this documentation for significant changes
5. Add tests for new functionality
6. Use meaningful commit messages

## License

See LICENSE file for details.

## Contact

For questions about the codebase or architecture decisions, please open an issue on GitHub.
