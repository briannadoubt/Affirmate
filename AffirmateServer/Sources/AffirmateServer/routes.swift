import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return req.view.render("index", ["title": "Hello Vapor!"])
    }
    app.get("hello") { request in
        return "Hello!!!!"
    }
    try app.register(collection: AuthenticationRouteCollection())
    try app.register(collection: MeRouteCollection())
    try app.register(collection: ChatRouteCollection())
    
}
