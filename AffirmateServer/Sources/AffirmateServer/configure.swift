import Fluent
import FluentPostgresDriver
import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Use PostGreSQL as a database. Connect to localhost if running in DEBUG, otherwise use environment variables for an integrated environment.
    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "vapor_database"
    ), as: .psql)

    // Configure migrations
    app.migrations.add(Chat.Migration())
    app.migrations.add(User.Migration())
    app.migrations.add(SessionToken.Migration())
    app.migrations.add(Message.Migration())
    app.migrations.add(Participant.Migration())
    
    // Log level
    #if DEBUG
    app.logger.logLevel = .debug
    #endif
    
    // Configure using Leaf as an HTML rendering engine for web browser clients.
    app.views.use(.leaf)
    
    // Add HMAC with SHA-256 signer.
    app.jwt.signers.use(.hs256(key: "secret"))
    
    // Configure Apple app identifier.
    app.jwt.apple.applicationIdentifier = "..."
    
    // Configure Google app identifier and domain name.
    app.jwt.google.applicationIdentifier = "..."
    app.jwt.google.gSuiteDomainName = "..."
    
    // MARK: Clear Database
    if app.environment == .testing {
        try? app.autoRevert().wait()
    }
    if !app.environment.isRelease {
        try? app.autoMigrate().wait()
    }
    do {
        // register routes
        try routes(app)
    } catch {
        print(error.localizedDescription)
    }
}
