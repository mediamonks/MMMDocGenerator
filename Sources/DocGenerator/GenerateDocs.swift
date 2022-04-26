import ArgumentParser
import Foundation
import MMMCommonCore

var outcome = [[String: Any]]()

@main
internal struct GenerateDocs: ParsableCommand {
    
    @Option(
        name: .shortAndLong,
        help: "The name of the project, could be specified in DocGenerator.json as well"
    )
    public var projectName: String?
    
    @Option(
        name: .shortAndLong,
        help: "The name or path to a custom theme, could be specified in DocGenerator.json as well"
    )
    public var themeNameOrPath: String?
    
    @Option(
        name: .shortAndLong,
        help: "Extra logging"
    )
    public var verbose: Bool = true
    
    public mutating func run() throws {
        
        let path = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        
        let options: GeneratorOptions = try {
            guard let optionsData = try? Data(contentsOf: path.appendingPathComponent("DocGenerator.json")) else {
                return .default
            }
            
            return try JSONDecoder().decode(GeneratorOptions.self, from: optionsData)
        }()

        guard let name = projectName ?? options.projectName else {
            throw NSError.mmm_error(withDomain: "Generator", message: "No project name specified")
        }

        let excludeList = (options.excludeList ?? []).map {
            $0.mmm_stringBySubstitutingVariables([
                "PROJECT_NAME": name
            ])
        }
        
        if let swiftPath = options.swiftPath {
            let files = swiftPath.mmm_stringBySubstitutingVariables([
                "PROJECT_NAME": name
            ])
            
            try walk(directory: path.appendingPathComponent(files), processAsObjC: false, exclude: excludeList)
        }
        
        if let objcPath = options.objcPath {
            let files = objcPath.mmm_stringBySubstitutingVariables([
                "PROJECT_NAME": name
            ])
            
            try walk(directory: path.appendingPathComponent(files), processAsObjC: true, exclude: excludeList)
        }
        
        let outcomeData = try JSONSerialization.data(withJSONObject: outcome, options: [])
        try outcomeData.write(to: path.appendingPathComponent("docs.json"))
        
        let themeName = themeNameOrPath ?? options.themeNameOrPath ?? "./MMMDocGenerator/Assets/Themes/mediamonks"
        
        print(try shell("jazzy --sourcekitten-sourcefile docs.json --theme \(themeName)"))
    }
    
    private mutating func walk(directory: URL, processAsObjC: Bool, exclude: [String]) throws {
        
        var isRootDir: ObjCBool = false
        
        guard
            FileManager.default.fileExists(atPath: directory.path, isDirectory: &isRootDir),
            isRootDir.boolValue
        else {
            // No directory, let's skip.
            return
        }
        
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        
        try files.forEach { url in
            
            let shouldExclude = exclude.contains { e in
                url.path.contains(e)
            }
            
            guard !shouldExclude else {
                return
            }
            
            if processAsObjC {
                guard url.path.contains(".h") else {
                    var isDir: ObjCBool = false
                    
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        try walk(directory: url, processAsObjC: true, exclude: exclude)
                    }
                    return
                }
                
                try process(filePath: url.path, processAsObjC: processAsObjC)
            } else {
                guard url.path.contains(".swift") else {
                    var isDir: ObjCBool = false
                    
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        try walk(directory: url, processAsObjC: false, exclude: exclude)
                    }
                    return
                }
                
                try process(filePath: url.path, processAsObjC: processAsObjC)
            }
        }
    }
    
    private mutating func process(filePath: String, processAsObjC: Bool) throws {
        
        let cleanPath = filePath.replacingOccurrences(
            of: FileManager.default.currentDirectoryPath + "/",
            with: ""
        )
        
        print("Processing swift file: \(cleanPath)")
        
        let output: String = try {
            if processAsObjC {
                return try shell("sourcekitten doc --objc \(filePath) -- -x objective-c  -isysroot $(xcrun --show-sdk-path --sdk iphonesimulator) -I $(pwd) -fmodules")
            } else {
                return try shell("sourcekitten doc --single-file \(filePath)")
            }
        }()
        
        let outputData = try output.data(using: .utf8).unwrap(orThrow: NSError.mmm_error(
            withDomain: "Generator",
            message: "Could not read output data"
        ))
        
        guard let object = try? JSONSerialization.jsonObject(with: outputData) else {
            print("Invalid data for \(cleanPath), skipping")
            return
        }
        
        if processAsObjC {
            
            guard case let data as [[String: Any]] = object else {
                throw NSError.mmm_error(withDomain: "Generator", message: "Invalid JSON structure?")
            }
            
            outcome.append(contentsOf: data)
            
        } else {
            guard case let data as [String: Any] = object else {
                throw NSError.mmm_error(withDomain: "Generator", message: "Invalid JSON structure?")
            }
            
            outcome.append(data)
        }
    }
    
    private func shell(_ command: String) throws -> String {
        
        if verbose {
            print("Running command: \(command)")
        }
        
        let task = Process()
        let pipe = Pipe()
        
        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)
        
        return try output.unwrap(
            orThrow: NSError.mmm_error(
                withDomain: "Generator",
                message: "Could not read pipe data"
            )
        )
    }
}
