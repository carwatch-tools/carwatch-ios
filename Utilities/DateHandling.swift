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
