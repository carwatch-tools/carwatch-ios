import Foundation


func getDayHourMinuteFromTime(time: Date) -> (Int, Int, Int) {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: time)
    let minute = calendar.component(.minute, from: time)
    let day = calendar.component(.day, from: time)
    return (day, hour, minute)
}

func getHourMinFormattedString(time: Date) -> String {
    let (_, hour, minute) = getDayHourMinuteFromTime(time: time)
    return "\(String(format: "%02d", hour)):\(String(format: "%02d", minute))"
}

func getDateTomorrowMorning() -> Date {
    /// returns a date object referring to 8am the next day from now
    /// defaults to current date and time if construction fails
    let calendar = Calendar.current
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        
        tomorrowComponents.hour = 8
        tomorrowComponents.minute = 0
        
        if let tomorrowMorning = calendar.date(from: tomorrowComponents) {
            return tomorrowMorning
        }
    }
    print("getDateTomorrowMorning failed")
    return Date()
}

func getUnixTimeMillisFromDateComponent(_ dc: DateComponents) -> Int {
    /// returns the time since 1st January 1970 in milliseconds from a date component
    let calendar = Calendar.current
    if let date = calendar.date(from: dc) {
        return Int(date.timeIntervalSince1970 * 1000)
    }
    print("getUnixTimeMillisFromDateComponent failed")
    return 0
}

func getUnixTimeSecondsFromDateComponent(_ dc: DateComponents) -> TimeInterval {
    /// returns the time since 1st January 1970 in seconds from a date component
    let calendar = Calendar.current
    if let date = calendar.date(from: dc) {
        return date.timeIntervalSince1970
    }
    print("getUnixTimeSecondsFromDateComponent failed")
    return 0
}

func translateUnixTimestamp(timeSeconds: TimeInterval) -> String {
    /// returns unix timestamp formatted to human-readable string
    let date = Date(timeIntervalSince1970: timeSeconds)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EE MMM dd yyyy HH:mm:ss ZZZZ"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter.string(from: date)
}
