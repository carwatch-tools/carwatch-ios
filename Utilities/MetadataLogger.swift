import Foundation
import SwiftUI

func logDeviceProperties() {
    let device = UIDevice.current
    var msg = [String: Any]()
    msg[LoggerConstants.loggerExtraPhoneBrand] = "Apple"
    msg[LoggerConstants.loggerExtraPhoneModel] = device.model
    msg[LoggerConstants.loggerExtraPhoneVersionSdkLevel] = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    msg[LoggerConstants.loggerExtraPhoneVersionRelease] = device.systemVersion
    Logger.instance.log(tag: LoggerConstants.loggerActionAppMetadata, message: msg)
}

func logAppMetadata() {
    let appName = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    let appVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    var msg = [String: Any]()
    msg[LoggerConstants.loggerExtraAppVersionName] = appName
    msg[LoggerConstants.loggerExtraAppVersionCode] = appVersion
    Logger.instance.log(tag: LoggerConstants.loggerActionAppMetadata, message: msg)
}

func logStudyData(studyData: StudyData){
    let samplePrefix = studyData.startSample.prefix(1)
    var startSampleIdx = 0
    if let startIdxFromStudyData = Int(studyData.startSample.dropFirst()) {
        startSampleIdx = startIdxFromStudyData
    }
    let salivaIds = (0..<(studyData.salivaDistances.count + studyData.salivaTimes.count)).map { i in
        let sampleIdx = startSampleIdx + i
        return "\(samplePrefix)\(sampleIdx)"
    }

    var msg = [String: Any]()
    msg[LoggerConstants.loggerExtraStudyName] = studyData.studyName
    msg[LoggerConstants.loggerExtraNumParticipants] = studyData.numParticipants
    msg[LoggerConstants.loggerExtraSalivaDistances] = studyData.salivaDistances
    msg[LoggerConstants.loggerExtraSalivaTimes] = studyData.salivaTimes
    msg[LoggerConstants.loggerExtraStudyDays] = studyData.studyDays
    msg[LoggerConstants.loggerExtraSalivaIds] = salivaIds
    msg[LoggerConstants.loggerExtraHasEveningSalivette] = studyData.hasEveningSample
    msg[LoggerConstants.loggerExtraShareEmailAddress] = studyData.shareEmailAdress
    msg[LoggerConstants.loggerExtraCheckDuplicates] = studyData.isCheckDuplicatesEnabled
    Logger.instance.log(tag: LoggerConstants.loggerActionStudyData, message: msg)
}

func logParticipantId(participantId: String){
    var msg = [String: Any]()
    msg[LoggerConstants.loggerExtraParticipantId] = participantId
    Logger.instance.log(tag: LoggerConstants.loggerActionParticipantIdSet, message: msg)
}
