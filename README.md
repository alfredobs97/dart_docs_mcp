# Dart Docs MCP Server

A local Model Context Protocol (MCP) server that provides an AI agent with the ability to fetch documentation context for Dart packages from pub.dev.

## Features

- Fetches package metadata from pub.dev API.
- Automatically discovers the package's GitHub repository.
- Extracts the main `README.md`.
- Extracts the `example` directory contents, specifically `example/README.md` and the entire `example/lib` folder, to give the AI agent concrete usage examples.

## Installation

### Via Homebrew (macOS & Linux)

You can install the `dart-docs-mcp` globally without needing the Dart SDK installed:

```bash
brew tap alfredobs97/tap
brew install dart-docs-mcp
```

This will make the `dart-docs-mcp` command available globally.

## Running Locally (Development)

To run the server locally, simply execute:

```bash
dart run bin/dart_docs_mcp.dart
```

This starts the MCP Server on standard input/output (stdio), which is standard for MCP clients (like Claude, Gemini CLI, or Google Antigravity).

### Using Docker (No installation required)

If you don't want to install Dart or FVM locally, you can use Docker.

#### For Development/Testing:
This runs the server using `dart run`, which is faster for iterating as it doesn't require a full AOT compilation.

```bash
docker build --target dev -t dart-docs-mcp:dev .
docker run -i dart-docs-mcp:dev
```

#### For Production:
This builds a minimal image with a native AOT-compiled binary.

```bash
docker build --target runtime -t dart-docs-mcp:latest .
docker run -i dart-docs-mcp:latest
```

## Tools Exposed

- `get_package_docs`: Given a `package_name`, it returns the compiled context consisting of the README and example files.

## Adding to an MCP Client

### Example for Claude Desktop
Add this to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "dart_docs_mcp": {
      "command": "dart-docs-mcp",
      "args": []
    }
  }
}
```

### Example for Gemini CLI
You can configure the MCP server in Gemini CLI either globally (`~/.gemini/settings.json`) or at the project level (`.gemini/settings.json`). Add the following inside your settings file:

```json
{
  "mcpServers": {
    "dart_docs_mcp": {
      "command": "dart-docs-mcp",
      "args": []
    }
  }
}
```

*Tip:* You can also add it without manually editing the file by using the Gemini CLI configuration command:
```bash
gemini mcp add local stdio dart_docs_mcp --command dart-docs-mcp
```

### Example for Google Antigravity IDE
Google Antigravity allows you to easily connect local MCP servers directly through its user interface:

1. Open Antigravity and go to the **Agent session** window.
2. Click the **"..." (Options)** dropdown menu at the top of the editor's side panel.
3. Select **MCP Servers** and then choose **Manage MCP**.
4. Click on **View Config** and paste your JSON configuration into the editor:

```json
{
  "mcpServers": {
    "dart_docs_mcp": {
      "command": "dart-docs-mcp",
      "args": []
    }
  }
}
```

5. Save the configuration and click the **Refresh** button. The `get_package_docs` tool will now be natively available to your Antigravity AI agents to fetch Dart package context on demand.

## Testing

Run unit tests via:

```bash
dart test
```