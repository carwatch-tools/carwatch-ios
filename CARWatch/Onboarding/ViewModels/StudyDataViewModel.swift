import Foundation

class StudyDataViewModel : ObservableObject {
    
    @Published var studyData = StudyDataViewModel.emptyStudyData() {
        didSet {
            saveStudyData()
        }
    }
    
    private var propertyMap: [String: String] = [:]
    let studyDataKey = "study_data"
    
    init() {
        getStudyData()
    }
    
    func getStudyData() {
        guard
            let data = UserDefaults.standard.data(forKey: studyDataKey),
            let savedData = try? JSONDecoder().decode(StudyData.self, from: data)
        else {
            return
        }
        self.studyData = savedData
    }
    
    func saveStudyData(){
        if let encodedStudyData = try? JSONEncoder().encode(studyData) {
            UserDefaults.standard.set(encodedStudyData, forKey: studyDataKey)
        }
    }

    func resetStudyData() {
        propertyMap.removeAll()
        studyData = StudyDataViewModel.emptyStudyData()
    }
    
    func parseQrCodeData(_ dataString: String) {
        propertyMap.removeAll()
        let properties = dataString.split(separator: QrParserConstants.separator).map { String($0) }
        
        if properties.isEmpty {
            studyData = studyData.setInvalid()
            return
        }
        
        if properties[0] != QrParserConstants.appId {
            studyData = studyData.setInvalid()
            return
        }
        
        for property in properties {
            if property == QrParserConstants.appId {
                continue
            }
            
            let pair = property.split(separator: QrParserConstants.specifier).map { String($0) }
            let key = pair[0]
            let value = pair.count > 1 ? pair[1] : ""
            propertyMap[key] = value
        }
        
        let studyName = getStringProperty(QrParserConstants.studyNameProperty)
        let salivaDistances = getStringProperty(QrParserConstants.salivaDistancesProperty)
        let salivaTimes = getStringProperty(QrParserConstants.salivaTimesProperty)
        let startSample = getStringProperty(QrParserConstants.startSampleProperty)
        let studyDays = getIntProperty(QrParserConstants.studyDaysProperty)
        let numParticipants = getIntProperty(QrParserConstants.numParticipantsProperty)
        let hasEveningSample = getIntProperty(QrParserConstants.eveningProperty) == 1
        let shareEmailAddress = getStringProperty(QrParserConstants.contactProperty)
        let isCheckDuplicatesEnabled = getIntProperty(QrParserConstants.duplicatesProperty) == 1
        let participantId = getStringProperty(QrParserConstants.participantIdProperty,isMandatory: false)
        
        studyData = StudyData(isValid: true, studyName: studyName, salivaDistancesString: salivaDistances, salivaTimesString: salivaTimes, startSample: startSample, studyDays: studyDays, numParticipants: numParticipants, hasEveningSample: hasEveningSample, shareEmailAdress: shareEmailAddress, isCheckDuplicatesEnabled: isCheckDuplicatesEnabled, participantId: participantId)
        if !isParticipantIdRequired(){
            logDeviceProperties()
            logAppMetadata()
            logStudyData(studyData: studyData)
            logParticipantId(participantId: participantId)
        }
    }
    
    private func getStringProperty(_ key: String, isMandatory: Bool = true) -> String {
        if let value = propertyMap[key] {
            return value
        }
        
        if isMandatory {
            studyData = studyData.setInvalid()
        }
        
        return ""
    }
    
    private func getIntProperty(_ key: String) -> Int {
        guard let value = propertyMap[key] else {
            studyData = studyData.setInvalid()
            return 0
        }
        
        if let intValue = Int(value) {
            return intValue
        } else {
            studyData = studyData.setInvalid()
            return 0
        }
    }
    
    func isParticipantIdRequired() -> Bool {
        return studyData.participantId.isEmpty
    }

    private static func emptyStudyData() -> StudyData {
        StudyData(isValid: false, studyName: "", salivaDistancesString: "", salivaTimesString: "", startSample: "", studyDays: 0, numParticipants: 0, hasEveningSample: false, shareEmailAdress: "", isCheckDuplicatesEnabled: false)
    }
}
