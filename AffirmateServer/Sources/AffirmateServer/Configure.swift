import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Leaf
import Vapor
import VaporAPNS
import APNS
import APNSCore
import JWT
import Crypto

fileprivate func configureDatabase(for app: Application) {
    if app.environment == .testing {
        app.databases.use(.sqlite(.memory), as: .sqlite)
        app.databases.default(to: .sqlite)
    } else {
        // Use PostGreSQL as a database. Connect to localhost if running in DEBUG, otherwise use environment variables for an integrated environment.
        var configuration = SQLPostgresConfiguration(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
            password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
            database: Environment.get("DATABASE_NAME") ?? "vapor_database",
            tls: .disable
        )

        if let searchPath = Environment.get("DATABASE_SEARCH_PATH") {
            configuration.searchPath = searchPath
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        app.databases.use(
            .postgres(configuration: configuration),
            as: .psql
        )
        app.databases.default(to: .psql)
    }
    
    // Configure migrations
    app.migrations.add(User.Migration())
    app.migrations.add(Chat.Migration())
    app.migrations.add(PublicKey.Migration())
    app.migrations.add(Participant.Migration())
    app.migrations.add(ChatInvitation.Migration())
    app.migrations.add(SessionToken.Migration())
    app.migrations.add(SessionToken.ExpiryMigration())
    app.migrations.add(Message.Migration())
}

func apnsEnvironment(for environment: Environment) -> APNSEnvironment {
    switch environment {
    case .production:
        return .production
    default:
        return .development
    }
}

fileprivate func configureApns(for app: Application) async throws {
    if
        let apnsKey = Environment.get("APNS_KEY")?.replacingOccurrences(of: "\\n", with: "\n"),
        let keyIdentifier = Environment.get("APNS_KEY_ID"),
        let teamIdentifier = Environment.get("APNS_TEAM_ID")
    {
        let iOSBundleIdentifier = "org.affirmate.Affirmate"
//        let watchOSBundleIdentifier = "org.affirmate.Affirmate.Watch"

        let apnsPrivateKey = try P256.Signing.PrivateKey(pemRepresentation: apnsKey)
        let apnsAuthentication: APNSClientConfiguration.AuthenticationMethod = .jwt(
            privateKey: apnsPrivateKey,
            keyIdentifier: keyIdentifier,
            teamIdentifier: teamIdentifier
        )
        let environment = apnsEnvironment(for: app.environment)

        let configuration = APNSClientConfiguration(
            authenticationMethod: apnsAuthentication,
            environment: environment
        )

        let isProductionEnvironment = environment.url == APNSEnvironment.production.url
        let containerID: APNSContainers.ID = isProductionEnvironment ? .production : .default

        let containers = await app.apns.containers
        await containers.use(
            configuration,
            eventLoopGroupProvider: .shared(app.eventLoopGroup),
            responseDecoder: JSONDecoder(),
            requestEncoder: JSONEncoder(),
            as: containerID,
            isDefault: true
        )

        if !isProductionEnvironment {
            var productionConfiguration = configuration
            productionConfiguration.environment = .production
            await containers.use(
                productionConfiguration,
                eventLoopGroupProvider: .shared(app.eventLoopGroup),
                responseDecoder: JSONDecoder(),
                requestEncoder: JSONEncoder(),
                as: .production,
                isDefault: false
            )
        }

        if app.environment == .production {
            precondition(isProductionEnvironment, "Production environment must use APNS production environment.")
        }

        // Add an ECDSA key to the JWT insfrustructure with an ES-256 signer.
        let jwtPrivateKey = try ES256PrivateKey(pem: apnsKey)
        await app.jwt.keys.add(ecdsa: jwtPrivateKey, kid: keyIdentifier.jwkIdentifier)

        // Configure Apple app identifier.
        app.jwt.apple.applicationIdentifier = iOSBundleIdentifier
    }
}

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    configureDatabase(for: app)
    
    // Log level
    #if DEBUG
    app.logger.logLevel = .debug
    #endif
    
    try await configureApns(for: app)
    
    // Configure Google app identifier and domain name.
//    app.jwt.google.applicationIdentifier = "org.affirmate.Affirmate"
//    app.jwt.google.gSuiteDomainName = "..."
    
    // Register Routes
    do {
        try app.register(collection: AuthenticationRouteCollection())
        try app.register(collection: MeRouteCollection())
        try app.register(collection: UserRouteCollection())
        try app.register(collection: ChatRouteCollection())
    } catch {
        print(error)
        throw error
    }
    
    let chatWebSocketManager = ChatWebSocketManager(eventLoop: app.eventLoopGroup.next())
    app
        .grouped(SessionToken.authenticator(), SessionToken.expirationMiddleware(), SessionToken.guardMiddleware())
        .webSocket("chats", ":chatId") { request, webSocket async in
            await chatWebSocketManager.connect(request, webSocket)
        }
}
