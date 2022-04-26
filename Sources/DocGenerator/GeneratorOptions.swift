import Foundation

internal struct GeneratorOptions: Codable {
    
    public let projectName: String?
    public let themeNameOrPath: String?
    public let swiftPath: String?
    public let objcPath: String?
    public let excludeList: [String]?
    
    public static let `default` = GeneratorOptions(
        projectName: nil,
        themeNameOrPath: nil,
        swiftPath: "Sources/${PROJECT_NAME}/",
        objcPath: "Sources/${PROJECT_NAME}ObjC/",
        excludeList: [
            "Sources/${PROJECT_NAME}ObjC/include"
        ]
    )
}
