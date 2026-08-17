import Foundation

/// UserDefaults keys for this app. NotionAuth/NotionManager read these rather
/// than Dosa's, so a token from one app can never be mistaken for the other.
enum AppSettings {
    static let appearanceKey = "pokebinder.appearance"
    static let typeEraKey = "pokebinder.typeEra"

    static let notionClientIdKey = "pokebinder.notionClientId"
    static let notionAccessTokenKey = "pokebinder.notionAccessToken"
    static let notionRefreshTokenKey = "pokebinder.notionRefreshToken"
    static let notionTokenExpiryKey = "pokebinder.notionTokenExpiry"
    static let notionTokenEndpointKey = "pokebinder.notionTokenEndpoint"
    static let notionWorkspaceKey = "pokebinder.notionWorkspaceName"

    /// Already wired on `SettingsSheet` as `@AppStorage("notionDatabaseId")`.
    static let notionDatabaseIdKey = "notionDatabaseId"
    static let defaultDatabaseId = "187a66ca-0d0d-40da-b3aa-64f51adceb65"
}
