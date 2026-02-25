# Dart Docs MCP Server

A local Model Context Protocol (MCP) server that provides an AI agent with the ability to fetch documentation context for Dart packages from pub.dev.

## Features

- Fetches package metadata from pub.dev API.
- Automatically discovers the package's GitHub repository.
- Extracts the main `README.md`.
- Extracts the `example` directory contents, specifically `example/README.md` and the entire `example/lib` folder, to give the AI agent concrete usage examples.

## Requirements

- Dart SDK version ^3.0.0 or higher

## Running Locally

To run the server locally, simply execute:

```bash
dart run bin/dart_docs_mcp.dart
```

This starts the MCP Server on standard input/output (stdio), which is standard for MCP clients (like Claude, Gemini CLI, or Google Antigravity).

## Tools Exposed

- `get_package_docs`: Given a `package_name`, it returns the compiled context consisting of the README and example files.

## Adding to an MCP Client

### Example for Claude Desktop
Add this to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "dart_docs_mcp": {
      "command": "dart",
      "args":[
        "run",
        "bin/dart_docs_mcp.dart"
      ],
      "cwd": "/absolute/path/to/dart_docs_mcp"
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
      "command": "dart",
      "args":[
        "run",
        "bin/dart_docs_mcp.dart"
      ],
      "cwd": "/absolute/path/to/dart_docs_mcp"
    }
  }
}
```

*Tip:* You can also add it without manually editing the file by using the Gemini CLI configuration command:
```bash
gemini mcp add local stdio dart_docs_mcp --command dart --args "run bin/dart_docs_mcp.dart" --cwd "/absolute/path/to/dart_docs_mcp"
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
      "command": "dart",
      "args":[
        "run",
        "bin/dart_docs_mcp.dart"
      ],
      "cwd": "/absolute/path/to/dart_docs_mcp"
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