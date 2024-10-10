import Foundation
import ZIPFoundation

class Logger {
    static let instance = Logger() // Singleton
    
    private var currentLogFile: URL? = nil
    private var studyName: String? = nil
    private var participantId: String? = nil
    
    func setStudyData(studyName: String?, participantId: String?) {
        self.studyName = studyName
        self.participantId = participantId
    }
    
    func log(tag: String, message: [String:Any]) {
        let timestamp = Date().timeIntervalSince1970
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        let humanReadableTime = dateFormatter.string(from: Date())
        
        // Convert the message dictionary content to JSON data
        if let jsonMessage = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted) {
            // Convert JSON data to humand readale string
            if let stringMessage = String(data: jsonMessage, encoding: .utf8) {
                print(stringMessage) // This is the string representation of the JSON
                let logEntry = "\(timestamp);\(humanReadableTime);\(tag);\(stringMessage)\n"
                if let fileURL = getCurrentLogFile() {
                    appendLog(logEntry, to: fileURL)
                }
            }
        }
    }
    
    private func getCurrentLogFile() -> URL? {
        /// get the name of the current log file
        let fileManager = FileManager.default
        let logsDirectory = getLogsDirectory()
        
        // Create logs directory if it does not exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            do {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create logs directory: \(error)")
                return nil
            }
        }
        
        // construct the name of the current file
        var studyInfo = ""
        if studyName != nil && participantId != nil {
            studyInfo = "\(studyName!)_\(participantId!)_"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let currentDate = dateFormatter.string(from: Date())
        let logFileName = "carwatch_\(studyInfo)\(currentDate).csv"
        
        // get file pointer
        let logFileURL = logsDirectory.appendingPathComponent(logFileName)
        
        // If the file does not exist, create it
        if !fileManager.fileExists(atPath: logFileURL.path) {
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        print("log file url: \(logFileURL)")
        return logFileURL
    }
    
    private func getLogsDirectory() -> URL {
        /// Get the directory where logs are stored, in this case the Documents/carwatchLogs directory of the CARWatch app home folder
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDirectory = documentsDirectory.appendingPathComponent("carwatchLogs")
        return logsDirectory
    }
    
    private func getZippedLogsDirectory() -> URL {
        /// Get the directory where zipped logs are stored, in this case the Documents/zippedCarwatchLogs directory of the CARWatch app home folder
        let logsDirectory = getLogsDirectory()
        // construct the name of the archive
        var fileName = "logs"
        if studyName != nil && participantId != nil {
            fileName += "_\(studyName!)_\(participantId!)"
        }
        fileName += ".zip"
        let zippedLogsDirectory = logsDirectory.appendingPathComponent(fileName)
        return zippedLogsDirectory
    }
    
    private func appendLog(_ logEntry: String, to fileURL: URL) {
        /// append an entry to the log file
        do {
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                // Append to existing file
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
                print("log file exists: \(fileURL)")
            } else {
                // Create a new file and write the log entry
                try logEntry.write(to: fileURL, atomically: true, encoding: .utf8)
                print("log file created: \(fileURL)")
            }
        } catch {
            print("Failed to write log: \(error)")
        }
    }
    
    func zipCurrentLogDirectoryContent() -> URL? {
        let fileManager = FileManager()
        let sourceURL = getLogsDirectory()
        let destinationURL = getZippedLogsDirectory()
        
        // Check if a ZIP file already exists at the destination, and remove if it does
        if fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.removeItem(at: destinationURL)
            } catch {
                print("Failed to remove existing ZIP file with error: \(error)")
                return nil
            }
        }
        
        // create new ZIP file
        do {
            try fileManager.zipItem(at: sourceURL, to: destinationURL)
        } catch {
            print("Creation of ZIP archive failed with error:\(error)")
            return nil
        }
        return destinationURL
        
        // Create an empty ZIP file at the destination
        //        do {
        //            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        //
        //            // TODO: fix access mode selection
        //            // Initialize the archive (ZIP file)
        //            var accessMode = fileManager.fileExists(atPath: destinationURL.absoluteString) ?  Archive.AccessMode.update :  Archive.AccessMode.create
        //            print("file exists? \(fileManager.fileExists(atPath: destinationURL.absoluteString))")
        //            print("\(destinationURL.absoluteString): \(accessMode)")
        //            accessMode = .update
        //            let archive = try Archive(url: destinationURL, accessMode: accessMode)
        //            print("archive modified")
        //            // Enumerate all files and subdirectories in the source directory
        //            let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        //            let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: keys, options: [], errorHandler: { (url, error) -> Bool in
        //                print("Error while enumerating files: \(error)")
        //                return true
        //            })
        //
        //            // Add each file to the archive (ZIP file)
        //            for case let fileURL as URL in enumerator! {
        //                // Only add files, not directories
        //                let resourceValues = try fileURL.resourceValues(forKeys: Set(keys))
        //                if resourceValues.isRegularFile ?? false {
        //                    // Add the file to the archive
        //                    try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: sourceURL)
        //                }
        //            }
        //        } catch {
        //            print("Error creating ZIP file: \(error)")
        //            return nil
        //        }
        //        return destinationURL
    }
}
