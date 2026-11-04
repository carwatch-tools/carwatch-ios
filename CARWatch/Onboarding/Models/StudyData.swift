import Foundation

struct StudyData : Codable {
    var isValid : Bool = true
    var studyName: String
    var salivaDistances: [Int]
    var salivaTimes: [Time]
    var startSample: String
    var studyDays: Int
    var numParticipants: Int
    var participantId: String = ""
    var hasEveningSample: Bool
    var shareEmailAdress: String
    var isCheckDuplicatesEnabled: Bool
    var numSamples: Int
    var eveningSampleId: Int
    
    init(isValid: Bool, studyName: String, salivaDistancesString: String, salivaTimesString: String, startSample: String, studyDays: Int, numParticipants: Int, hasEveningSample: Bool, shareEmailAdress: String, isCheckDuplicatesEnabled: Bool, participantId: String = "") {
        self.isValid = isValid
        self.studyName = studyName
        self.salivaDistances = StudyData.parseSalivaDistances(salivaDistancesString: salivaDistancesString)
        self.salivaTimes = StudyData.parseSalivaTimes(salivaTimesString: salivaTimesString)
        self.startSample = startSample
        self.studyDays = studyDays
        self.numParticipants = numParticipants
        self.hasEveningSample = hasEveningSample
        self.shareEmailAdress = shareEmailAdress
        self.isCheckDuplicatesEnabled = isCheckDuplicatesEnabled
        self.participantId = participantId
        self.numSamples = StudyData.calculateNumSamples(hasEvening: hasEveningSample, salivaDistances: salivaDistances, salivaTimes: salivaTimes)
        self.eveningSampleId = StudyData.calculateEveningSampleId(hasEvening: hasEveningSample, numSamples: numSamples)
    }
    
    init(isValid: Bool, studyName: String, salivaDistances: [Int], salivaTimes: [Time], startSample: String, studyDays: Int, numParticipants: Int, hasEveningSample: Bool, shareEmailAdress: String, isCheckDuplicatesEnabled: Bool, participantId: String) {
        self.isValid = isValid
        self.studyName = studyName
        self.salivaDistances = salivaDistances
        self.salivaTimes = salivaTimes
        self.startSample = startSample
        self.studyDays = studyDays
        self.numParticipants = numParticipants
        self.hasEveningSample = hasEveningSample
        self.shareEmailAdress = shareEmailAdress
        self.isCheckDuplicatesEnabled = isCheckDuplicatesEnabled
        self.participantId = participantId
        self.numSamples = StudyData.calculateNumSamples(hasEvening: hasEveningSample, salivaDistances: salivaDistances, salivaTimes: salivaTimes)
        self.eveningSampleId = StudyData.calculateEveningSampleId(hasEvening: hasEveningSample, numSamples: numSamples)
    }
    
    func setInvalid() -> StudyData {
        return StudyData(isValid: false, studyName: studyName, salivaDistances: salivaDistances, salivaTimes: salivaTimes, startSample: startSample, studyDays: studyDays, numParticipants: numParticipants, hasEveningSample: hasEveningSample, shareEmailAdress: shareEmailAdress, isCheckDuplicatesEnabled: isCheckDuplicatesEnabled, participantId: participantId)
    }
    
    var description: String {
        return "valid: \(isValid), study name: \(studyName), saliva dist.: \(salivaDistances), saliva times: \(salivaTimes), start sample: \(startSample), study days: \(studyDays), #participants: \(numParticipants), evening: \(hasEveningSample), contact: \(shareEmailAdress), duplicates: \(isCheckDuplicatesEnabled), participant id: \(participantId)"
    }
    
    static private func parseSalivaDistances(salivaDistancesString: String) -> [Int]{
        if salivaDistancesString.isEmpty {
            return [Int]()
        }
        
        let splitList = salivaDistancesString.split(separator: Character(QrParserConstants.listSeparator))
        let output = splitList.compactMap { Int($0) }
        return output
    }
    
    static private func parseSalivaTimes(salivaTimesString: String) -> [Time]{
        if salivaTimesString.isEmpty {
            return [Time]()
        }
        
        
        let splitList = salivaTimesString.split(separator: Character(QrParserConstants.listSeparator))
        var output = [Time]()
        for time in splitList.map({String($0)}) {
            guard !time.isEmpty else { continue }
            
            let hours = String(time.prefix(2))
            let minutes = String(time.suffix(2))
            if let hour = Int(hours), let minute = Int(minutes) {
                output.append(Time(hour: hour, minute: minute))
            }
        }
        return output
    }
    
    static private func calculateNumSamples(hasEvening: Bool, salivaDistances: [Int], salivaTimes: [Time]) -> Int {
        let numEveningSamples = hasEvening ? 1 : 0
        let numMorningSamples = salivaDistances.count
        let numFixedSamples = salivaTimes.count
        let totalNumSamples = numFixedSamples + numMorningSamples + numEveningSamples
        return totalNumSamples
    }
    
    static private func calculateEveningSampleId(hasEvening: Bool, numSamples: Int) -> Int {
        return hasEvening ? numSamples - 1 : -1
    }
}

