# Dart Docs MCP Server

A local Model Context Protocol (MCP) server that provides an AI agent with the ability to fetch documentation context for Dart and Flutter packages from pub.dev.

## Features

- Fetches package metadata from pub.dev API.
- Automatically discovers the package's GitHub repository.
- Extracts the main `README.md`.
- Extracts the `example` directory contents, specifically `example/README.md` and the entire `example/lib` folder, to give the AI agent concrete usage examples.
- **Searches the internal `lib/` source code** of any package with a keyword or regex, returning file paths, line numbers, and context snippets — without cloning the repository.

## Architecture

This server is built using the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/), an open standard that enables AI models to interact with local and remote tools.

### How it Works
1. **Request**: An MCP client (like Claude or Antigravity) sends a JSON-RPC request to this server over standard input (`stdio`).
2. **Orchestration**: The `McpServer` handles the protocol handshake and routes the request to the appropriate tool implementation in `lib/mcp/tools/`.
3. **Execution**: The tools use internal services (`lib/src/`) to fetch data from:
    - **pub.dev API**: For package metadata and version info.
    - **pub.dev Assets**: For pre-rendered Dartdoc `index.json` (API surface).
    - **Package Archives**: Downloaded and extracted in-memory to fetch READMEs and examples.
    - **GitHub**: Fallback for direct repository inspection.
4. **Response**: The gathered context is formatted as a `CallToolResult` and sent back to the client to be injected into the LLM's context.

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

| Tool | Description |
|------|-------------|
| `get_package_docs` | Fetches the README and `example/` directory of a package. Best for getting a general overview and concrete usage examples. |
| `get_api_surface` | Fetches a concise "virtual header" of all public classes, methods, and enums from a package's `index.json`. Ideal for understanding the public API without reading full source files. |
| `get_type_hierarchy` | Reconstructs the inheritance tree for a specific class (e.g., finding all implementations of a sealed class). |
| `cross_reference` | Maps conceptual features from a README to specific implementation files using GitHub search. |
| `search_package_code` | **Greps the internal `lib/` source files** of a package for a keyword or regex. Returns file paths, 1-based line numbers, and ±3-line context snippets. Generated files (`.g.dart`, `.freezed.dart`, etc.) are automatically excluded. Results are capped at 15 matches. |

## Local Testing & Debugging

The easiest way to test your MCP server locally is using the [`mcp_dart_cli`](https://github.com/leehack/mcp_dart?tab=readme-ov-file#quick-start-with-cli) tool.

### Testing with the CLI
Once you have the server running or built, you can use the inspector to call tools manually:

1. **Install the CLI**:
   ```bash
   dart pub global activate mcp_dart_cli
   ```

2. **Run a tool query**:
   ```bash
   # Fetch README + examples
   mcp_dart inspect --tool get_package_docs --json-args '{"package_name": "http"}'

   # Search the internal lib/ source code
   mcp_dart inspect --tool search_package_code \
     --json-args '{"package_name": "http", "search_query": "Client"}'
   ```

This is particularly useful for verifying that JSON-RPC communication is working correctly without needing to restart your IDE or AI client.

## Adding to an MCP Client

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

5. Save the configuration and click the **Refresh** button. The `get_package_docs` tool will now be natively available to your Antigravity AI agents to fetch Dart and Flutter package context on demand.

### Example for Claude Code
To use this with [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code), add it to your configuration:

```bash
claude mcp add dart_docs_mcp -- dart-docs-mcp
```

Or manually in your config file:
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

## Testing

Run unit tests via:

```bash
dart test
```