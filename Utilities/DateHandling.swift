import Foundation


func getHourAndMinuteFromTime(time: Date) -> (Int, Int, Int) {
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: time)
    let minute = calendar.component(.minute, from: time)
    let day = calendar.component(.day, from: time)
    return (day, hour, minute)
}
