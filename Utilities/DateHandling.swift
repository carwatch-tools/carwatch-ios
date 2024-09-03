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
    return Date()
}
