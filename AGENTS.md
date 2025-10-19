# Repository Guidelines

## Project Structure & Module Organization
The SwiftUI client lives in `Affirmate/`, with feature folders such as `Authentication`, `Chat`, `Network`, `Security`, and `Persistence`. Shared models and protocol helpers used by multiple targets are packaged in `AffirmateShared/` (`Sources/` and `Tests/`). The Vapor backend and its configuration sit in `AffirmateServer/` with `Sources/` for routes, `Public/` for assets, and `Tests/` for server specs. `AffirmateTests/`, `AffirmateUITests/`, and corresponding watch targets contain XCTest suites; watchOS and macOS apps mirror the iOS structure under their respective directories.

## Build, Test, and Development Commands
- `open Affirmate.xcodeproj` opens the multi-target project for client, watch, and server runtimes.
- `xcodebuild -scheme Affirmate -destination 'platform=iOS Simulator,name=iPhone 15' build` compiles the iOS client.
- `xcodebuild -scheme Affirmate -destination 'platform=iOS Simulator,name=iPhone 15' test` runs unit and UI tests.
- From `AffirmateServer/`: `docker-compose up db` launches the local Mongo/Postgres services, `vapor run migrate` applies schema changes, and `vapor run serve --hostname 0.0.0.0 --port 8080` starts the API.
- `cd AffirmateShared && swift test` validates shared package logic; `cd AffirmateServer && swift test` executes backend specs.

## Coding Style & Naming Conventions
Follow idiomatic Swift 5 style: four-space indentation, trailing commas for multiline literals, UpperCamelCase types, lowerCamelCase methods and properties, and suffix view models/services with `ViewModel` and `Service`. Keep SwiftUI body declarations concise and factor reusable UI into `Components/`. Prefer `Task`/`async` APIs over callbacks, and centralize security logic in `Security/`. Run Xcode’s “Editor > Structure > Re-Indent” or the Swift formatter before committing.

## Testing Guidelines
Use XCTest for client and shared modules, and XCTVapor for server tests. Add unit tests beside implementation folders (e.g., `AffirmateTests/Network` for `Network/` sources) and name methods `test_<Scenario>_Produces<Outcome>()`. Aim to cover encryption flows, persistence boundaries, and authentication edge cases; add integration tests whenever routes touch Mongo/Postgres migrations. Always run the relevant `xcodebuild` or `swift test` command before pushing changes.

## Commit & Pull Request Guidelines
Commit messages follow the repository’s imperative, sentence-style pattern (`Add CI workflow for client, server, and integration tests`). Group related changes into focused commits and include migration or schema updates in the same commit as their implementation. Pull requests should summarize user-facing impact, list test commands executed, and reference related issues. Attach screenshots or simulator recordings for UI tweaks and note any security or configuration steps needed for reviewers.

## Security & Configuration Tips
Secrets (APNS credentials, database URLs) rely on environment variables described in `AffirmateServer/README.md` and `docker-compose.yml`; never commit them. When testing push notifications, ensure the `APNS_*` variables match your development or production certificates. CloudKit and websocket keys should stay in local configuration files ignored by Git. Rotate credentials after sharing preview builds and document any temporary overrides in the PR description.
