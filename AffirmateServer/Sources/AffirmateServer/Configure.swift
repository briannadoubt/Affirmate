import Fluent
import FluentPostgresDriver
import Leaf
import Vapor
import APNS
import APNSwift
import JWT

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    if app.environment != .testing {
        // Use PostGreSQL as a database. Connect to localhost if running in DEBUG, otherwise use environment variables for an integrated environment.
        app.databases.use(.postgres(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database"
        ), as: .psql)
    }

    // Configure migrations
    app.migrations.add(AffirmateUser.Migration())
    app.migrations.add(Chat.Migration())
    app.migrations.add(Participant.Migration())
    app.migrations.add(ChatInvitation.Migration())
    app.migrations.add(SessionToken.Migration())
    app.migrations.add(Message.Migration())
    app.migrations.add(PublicKey.Migration())
    app.migrations.add(PreKey.Migration())
    
    // Log level
    #if DEBUG
    app.logger.logLevel = .debug
    #endif
    
    // Configure using Leaf as an HTML rendering engine for web browser clients.
//    app.views.use(.leaf)
    
    if
        let apnsKey = Environment.get("APNS_KEY")?.replacingOccurrences(of: "\\n", with: "\n"),
        let keyIdentifier = Environment.get("APNS_KEY_ID"),
        let teamIdentifier = Environment.get("APNS_TEAM_ID")
    {
        let iOSBundleIdentifier = "org.affirmate.Affirmate"
//        let watchOSBundleIdentifier = "org.affirmate.Affirmate.Watch"
//        let macOSBundleIdentifier = "org.affirmate.Affirmate"
        
        let key: ECDSAKey =  try .private(pem: apnsKey)
        
        let apnsAuthentication: APNSwiftConfiguration.AuthenticationMethod = .jwt(
            key: key,
            keyIdentifier: keyIdentifier.jwkIdentifier,
            teamIdentifier: teamIdentifier
        )
        
        switch app.environment {
        case .production:
            app.apns.configuration = APNSwiftConfiguration(
                authenticationMethod: apnsAuthentication,
                topic: iOSBundleIdentifier,
//                environment: .production
                environment: .sandbox
            )
        default:
            app.apns.configuration = APNSwiftConfiguration(
                authenticationMethod: apnsAuthentication,
                topic: iOSBundleIdentifier,
                environment: .sandbox
            )
        }
        
        // Add an ECDSA key to the JWT insfrustructure with an ES-256 signer.
        app.jwt.signers.use(.es256(key: key))
        
        // Configure Apple app identifier.
        app.jwt.apple.applicationIdentifier = iOSBundleIdentifier
    }
    
    // Configure Google app identifier and domain name.
//    app.jwt.google.applicationIdentifier = "org.affirmate.Affirmate"
//    app.jwt.google.gSuiteDomainName = "..."
    
    do {
        // MARK: Clear Database
        if app.environment == .testing {
            try app.autoRevert().wait()
        }
        if !app.environment.isRelease {
            try app.autoMigrate().wait()
        }
    } catch {
        print(error)
    }
    
    // Register Routes
    do {
        try app.register(collection: AuthenticationRouteCollection())
        try app.register(collection: MeRouteCollection())
        try app.register(collection: UserRouteCollection())
        try app.register(collection: ChatRouteCollection())
    } catch {
        print(error)
    }
    
    let chatWebSocketManager = ChatWebSocketManager(eventLoop: app.eventLoopGroup.next())
    app
        .grouped(SessionToken.authenticator(), SessionToken.guardMiddleware())
        .webSocket("chats", ":chatId") { request, webSocket async in
            await chatWebSocketManager.connect(request, webSocket)
        }
}


