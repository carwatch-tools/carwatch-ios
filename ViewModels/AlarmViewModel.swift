//
//  AlarmViewModel.swift
//  CARWatch
//
//  Created by Admin on 02.07.24.
//

import Foundation

class AlarmViewModel : ObservableObject {
    
    @Published var alarm: Alarm
    
    init() {
        alarm = Alarm(id: "initial", isActive: false, isScanned: false, salivaId: -1)
    }
    
    func getCurrentAlarm() -> Alarm {
        return alarm
    }
    
    func getTimeUntilNextAlarm() -> (Int, Int) {
        let timeInterval = NSInteger(alarm.time.timeIntervalSinceNow)
        let minutes = (timeInterval / 60) % 60
        let hours = (timeInterval / 3600)
        return (hours, minutes)
    }
    
    func toggleCurrentAlarm() {
        alarm = alarm.toggleIsActive()
    }
    
    func updateAlarmTime(time: Date) {
        var newTime: Date
        print("updating alarm time")
        if time.timeIntervalSinceNow.sign == .minus {
            print("sign is minus")
            // if selected date is in the past, select next day
            newTime = time.addingTimeInterval(3600 * 24)
        } else {
            newTime = time
        }
        alarm = alarm.updateTime(newTime: newTime)
    }
}
