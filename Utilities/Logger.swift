import Foundation
import ZIPFoundation

class Logger {
    static let instance = Logger() // Singleton
    
    private var currentLogFile: URL? = nil
    private var studyName: String? = nil
    private var participantId: String? = nil
    
    func setStudyData(studyName: String?, participantId: String?) {
        print("setting study data: \(studyName!), \(participantId!)")
        self.studyName = studyName
        self.participantId = participantId
    }
    
    func log(tag: String, message: [String:Any]) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) // unix time in ms
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EE MMM dd yyyy HH:mm:ss ZZZZ"
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
        
        if !createDirectoryIfNotExisting(directoryURL: logsDirectory){
            // directory creation failed
            return nil
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
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let logsDirectory = documentsDirectory.appendingPathComponent("zippedCarwatchLogs")
        
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
    
    private func createDirectoryIfNotExisting(directoryURL: URL) -> Bool {
        /// checks if the directory exists and creates it otherwise
        /// returns true when successful and false in case of an error
        let fileManager = FileManager.default
        // Create destination directory if it does not exist
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create directory \(directoryURL.lastPathComponent): \(error)")
                return false
            }
        }
        return true
    }
    
    func zipCurrentLogDirectoryContent() -> URL? {
        /// create zip archive from all present log files and return the link to it
        let fileManager = FileManager()
        let sourceURL = getLogsDirectory()
        let destinationURL = getZippedLogsDirectory()
        
        if !createDirectoryIfNotExisting(directoryURL: destinationURL) {
            // directory creation failed
            return nil
        }
        
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
    }
    
    func deleteAllLogFiles() {
        /// remove all log files present in Documents/carwatchLogs
        let fileManager = FileManager.default
        let logDirectory = getLogsDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            // Iterate through each file and delete it
            for filePath in filePaths {
                try fileManager.removeItem(at: filePath)
            }
            print("All files deleted from directory: \(logDirectory)")
        } catch let error {
            print("Error while deleting files: \(error.localizedDescription)")
        }
    }
}
