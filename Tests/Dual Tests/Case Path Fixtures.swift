public import Dual

@Cases
public enum Screen: Equatable {
    case home
    case list
    case detail(Int)
    case edit(id: Int, draft: String)
}

@Cases
public enum App: Equatable {
    case home
    case authenticate(Auth)
}

@Cases
public enum Auth: Equatable {
    case login
    case api(Api)
}

@Cases
public enum Api: Equatable {
    case status
    case credentials(Credentials)
}

public struct Credentials: Equatable {
    public let token: String
    public init(token: String) { self.token = token }
}

@Dual
public enum Outer: Sendable {
    case only

    @Cases
    public enum Inner: Equatable {
        case a(Int)
        case b
    }
}
