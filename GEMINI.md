# Gemini Context: Dart Docs MCP Server

This project is a [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) server implemented in Dart. It provides AI agents with tools to fetch documentation and usage examples for Dart & Flutter packages from pub.dev and GitHub, facilitating better code generation and review.

## Project Overview

- **Name:** `dart_docs_mcp`
- **Primary Technology:** [Dart SDK](https://dart.dev/)
- **Core Library:** [`mcp_dart`](https://pub.dev/packages/mcp_dart)
- **Key Features:**
    - Fetches package metadata from pub.dev.
    - Extracts `README.md` and files from the `example/` directory of Dart packages.
    - Supports both `stdio` and `StreamableHTTP` transports for MCP communication.
    - Provides specialized prompts for implementing features and reviewing code with specific packages.

## Architecture

The project follows a modular structure separating MCP protocol logic from the core business logic for fetching package documentation.

- `bin/server.dart`: The main entry point of the application. It handles CLI arguments and starts the MCP server using either `stdio` (default) or HTTP transport.
- `lib/mcp/`: Contains all MCP-specific components.
    - `mcp.dart`: Orchestrates the server configuration and registration of tools, resources, and prompts.
    - `tools/`: Implementations of MCP tools (e.g., `get_package_docs`).
    - `resources/`: Definitions of MCP resources (e.g., `popular_packages`).
    - `prompts/`: Pre-defined prompts for common AI workflows (e.g., `implement_with_package`).
- `lib/src/`: Core logic for interacting with external APIs.
    - `pub_service.dart`: Abstract interface for package documentation retrieval.
    - `pub_service_archive.dart`: Implementation that downloads and extracts package archives from pub.dev.
    - `pub_service_github.dart`: Implementation that fetches content directly from GitHub repositories.
- `test/`: Contains unit tests for both the MCP server and the internal services.

## Building and Running

### Development
To run the server locally using the `stdio` transport:
```bash
dart run bin/server.dart
```

To run with the HTTP transport:
```bash
dart run bin/server.dart -t http -p 3000
```

### Testing
Execute the test suite using:
```bash
dart test
```

You can also test the MCP tool directly using the `mcp_dart` inspector. First, install the CLI tool globally:
```bash
dart pub global activate mcp_dart_cli
```

Then, run the inspector:
```bash
mcp_dart inspect --tool get_package_docs --json-args '{"package_name": "feedback"}'
```

### Docker
The project includes a `Dockerfile` with multi-stage builds for both development and production (AOT compiled) environments.
```bash
# Production build
docker build --target runtime -t dart-docs-mcp:latest .
```

## Development Conventions

- **Logging:** Uses the `logging` package. Log levels and output (to `stderr`) are configured in `bin/server.dart`.
- **Error Handling:** Errors in tool execution are caught and returned as part of the MCP `CallToolResult`.
- **Linting:** Follows standard Dart linting rules as defined in `analysis_options.yaml`.
- **Dependencies:** Managed via `pubspec.yaml`. Use `dart pub get` to install.
