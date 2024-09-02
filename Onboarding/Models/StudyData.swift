import Foundation

struct StudyData : Codable {
    var isValid : Bool = true
    var studyName: String;
    var salivaDistances: [Int]
    var salivaTimes: [Int]
    var startSample: String
    var studyDays: Int
    var numParticipants: Int
    var participantId: String = ""
    var hasEveningSample: Bool
    var shareEmailAdress: String
    var isCheckDuplicatesEnabled: Bool
    
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
    }
    
    init(isValid: Bool, studyName: String, salivaDistances: [Int], salivaTimes: [Int], startSample: String, studyDays: Int, numParticipants: Int, hasEveningSample: Bool, shareEmailAdress: String, isCheckDuplicatesEnabled: Bool, participantId: String) {
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
    }
    
    func setInvalid() -> StudyData {
        return StudyData(isValid: false, studyName: studyName, salivaDistances: salivaDistances, salivaTimes: salivaTimes, startSample: startSample, studyDays: studyDays, numParticipants: numParticipants, hasEveningSample: hasEveningSample, shareEmailAdress: shareEmailAdress, isCheckDuplicatesEnabled: isCheckDuplicatesEnabled, participantId: participantId)
    }
    
    var description: String {
        return "valid: \(isValid), study name: \(studyName), saliva dist.: \(salivaDistances), saliva times: \(salivaDistances), start sample: \(startSample), study days: \(studyDays), #participants: \(numParticipants), evening: \(hasEveningSample), contact: \(shareEmailAdress), duplicates: \(isCheckDuplicatesEnabled), participant id: \(participantId)"
    }
    
    static private func parseSalivaDistances(salivaDistancesString: String) -> [Int]{
        return [Int]()
    }
    
    static private func parseSalivaTimes(salivaTimesString: String) -> [Int]{
        return [Int]()
    }
}


