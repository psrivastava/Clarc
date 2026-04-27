import Foundation

public struct CLISessionPreview {
    public let sessionId: String
    public let title: String
    public let projectPath: String
    public let modifiedAt: Date
    public let recentMessages: [String]

    public init(sessionId: String, title: String, projectPath: String, modifiedAt: Date, recentMessages: [String]) {
        self.sessionId = sessionId
        self.title = title
        self.projectPath = projectPath
        self.modifiedAt = modifiedAt
        self.recentMessages = recentMessages
    }
}
