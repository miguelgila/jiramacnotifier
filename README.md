# Jira Mac Notifier

A lightweight, native macOS application that provides desktop notifications for Jira issue updates. Monitor multiple Jira instances with custom JQL filters and get notified instantly when issues change.

## Features

- **Multi-Instance Support**: Connect to multiple Jira instances simultaneously
- **Custom JQL Filters**: Create custom JQL queries for each instance to monitor specific issues
- **Secure Token Storage**: API tokens are securely stored in the macOS Keychain
- **Configurable Polling**: Set custom polling intervals per instance (1-60 minutes)
- **Native Notifications**: Uses macOS Notification Center for non-intrusive alerts
- **Lightweight & Fast**: Built with Swift for optimal performance
- **Persistent State**: Tracks issue states using SQLite to detect changes
- **Standalone**: Ships as a single .app bundle with no external dependencies

## Requirements

- macOS 13.0 (Ventura) or later
- Jira Cloud or Jira Server with API access

## Installation

### From Release

1. Download the latest `JiraMacNotifier.zip` from the [Releases](https://github.com/yourusername/jiramacnotifier/releases) page
2. Extract the ZIP file
3. Drag `JiraMacNotifier.app` to your Applications folder
4. Launch the app

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/jiramacnotifier.git
cd jiramacnotifier

# Build the project
swift build -c release

# Or use the build script
./scripts/build-app.sh
```

## Configuration

### Getting a Jira API Token

1. Log in to your Jira instance
2. Go to Account Settings → Security → API Tokens
3. Click "Create API token"
4. Give it a name and copy the generated token

### Setting Up an Instance

1. Launch JiraMacNotifier
2. Click the "+" button to add a new instance
3. Fill in the details:
   - **Name**: A friendly name (e.g., "Work Jira")
   - **URL**: Your Jira instance URL (e.g., `https://your-company.atlassian.net`)
   - **Username**: Your Jira email address
   - **API Token**: Paste the token you created
   - **Poll Interval**: How often to check for updates (in minutes)
4. Click "Add"

### Creating Filters

1. Select an instance from the sidebar
2. Click "Add Filter" in the Filters section
3. Enter:
   - **Name**: Filter name (e.g., "My Open Issues")
   - **JQL Query**: Your Jira Query Language query
4. Click "Add"

#### Example JQL Queries

```jql
# Your assigned open issues
assignee = currentUser() AND status != Done

# High priority issues in a specific project
project = MYPROJ AND priority = High

# Issues updated in the last hour
updatedDate >= -1h

# Issues you're watching
watcher = currentUser() AND status NOT IN (Done, Closed)
```

## Usage

1. **Start Polling**: Click the play button in the toolbar to start monitoring
2. **Poll Now**: Click the refresh button to check immediately
3. **Stop Polling**: Click the pause button to stop monitoring
4. **Enable/Disable**: Toggle instances and filters on/off without deleting them

## Architecture

```
JiraMacNotifier/
├── Models.swift              # Data models for instances, filters, and issues
├── KeychainManager.swift     # Secure token storage using macOS Keychain
├── JiraClient.swift          # Jira REST API client
├── DatabaseManager.swift     # SQLite persistence for issue tracking
├── ConfigurationManager.swift # Instance and filter configuration
├── NotificationService.swift  # macOS notification integration
├── PollingService.swift       # Background polling and change detection
└── Views/                     # SwiftUI user interface
    ├── ContentView.swift
    ├── InstanceDetailView.swift
    └── AddInstanceView.swift
```

## Data Storage

- **Configuration**: `~/Library/Application Support/JiraMacNotifier/config.json`
- **Issue State Database**: `~/Library/Application Support/JiraMacNotifier/jira_notifier.db`
- **API Tokens**: macOS Keychain (service: `com.jiramacnotifier.tokens`)

## Development

### Running Tests

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Generate coverage report
xcrun llvm-cov report \
  .build/debug/JiraMacNotifierPackageTests.xctest/Contents/MacOS/JiraMacNotifierPackageTests \
  -instr-profile .build/debug/codecov/default.profdata
```

### CI/CD

The project uses GitHub Actions for continuous integration:

- **Tests**: Runs on every push and PR
- **Coverage**: Enforces minimum 70% code coverage
- **Linting**: SwiftLint checks code style
- **Build**: Creates distributable app bundle

## Security

- API tokens are stored in the macOS Keychain using `kSecClassGenericPassword`
- Tokens are never written to disk or logs
- All network communication uses HTTPS
- Tokens are only accessible to the app that created them

## Troubleshooting

### Notifications Not Appearing

1. Check System Preferences → Notifications → JiraMacNotifier
2. Ensure notifications are enabled
3. Check that the app is running and polling is active

### Connection Errors

1. Verify your API token is still valid
2. Check the Jira instance URL (should not include `/rest/api`)
3. Ensure you have network connectivity
4. Test the connection using the "Test Connection" button

### No Updates Detected

1. Verify your JQL query returns results in Jira's web interface
2. Check that the filter is enabled
3. Try clicking "Poll Now" to force an immediate check
4. Check the poll interval is appropriate

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [Swift](https://swift.org/)
- Uses [SQLite.swift](https://github.com/stephencelis/SQLite.swift) for database operations
