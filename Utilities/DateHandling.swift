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

func getUnixTimeMillisFromDate(_ date: Date) -> Int {
    /// returns the time since 1st January 1970 in milliseconds from a date
    return Int(date.timeIntervalSince1970 * 1000)
}

func formatDateForLogs(_ date: Date) -> String {
    /// returns human readable format of date for app logs
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "EE MMM dd yyyy HH:mm:ss ZZZZ"
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    return dateFormatter.string(from: date)
}
