# CARWatch App for iOS
## Developer Guide
### Getting started
For development, you need to have an Apple ID and a Mac with XCode installed. The latest XCode version can be retrieved from the app store. If your OS version is not compatible with the latest version, you can download an earlier version [here](https://developer.apple.com/download/all/?q=xcode) (requires sign-in with your apple id).

To get started, first clone the project:
```bash
git clone https://github.com/mad-lab-fau/carwatch-ios.git
```
Or when using SSH:
```bash
git clone git@github.com:mad-lab-fau/carwatch-ios.git
```
Next, make sure to reorder the directory structure as described in the [App Configuration](#app-configuration) section.
To deploy the app to a device, you need to sign-in to your apple account in XCode (Click on top-level project folder -> Signing & Capabilities -> Team -> Add account. In the accounts tab that is opening, you can add your apple id and also sign in to your github account for version control.
You can then run the app, either on an emulator, or a connected phone. The target device can be selected in the dropdown menu at the top middle of the editor. If you select to run the app on a physical device, a fresh deployment will likely cause an 'Untrusted Developer' alert on the device. To prevent this, search for 'VPN & Device Management' in the phone's settings and select your apple ID in the 'Developer App' section. Then select the 'Trust' button, confirm, and rerun the deployment.

### Compatibility
All used components are available for iOS 15 (iPhone 7, iPhone SE (gen 1), iPhone 6s) and upward. As of Oct. 2024, this covers [95.1%](https://iosref.com/ios-usage) of all iPhones in use. 
For development, Xcode Version 15.4 was used.

### App Configuration
In older versions of Xcode, the configuration was stored in a file called `Info.plist`. Since Xcode 13, this file only contains custom properties, which are not needed for CARWatch (so far).
Standard properties are stored in the `CARWatch.xcodeproj` folder. They can be accessed in human-readable format when opening this folder (equal to opening the project) in Xcode, clicking on the top-level project folder, and then accessing the 'Info' tab. The most important property in our case is the 'Privacy - Camera Usage Description' field, which contains a detailed explanation why CARWatch needs the camera permission and is mandatory for the app to be accepted for the app store. 
After pulling the Code from Github, the file structure will look like the following:

```bash
└── CARWatch
    ├── .git
    ├── CARWatch.xcodeproj
    ├── CarWatchApp.swift
    ├── Assets.xcassets
    └── Different feature folders
 ```

 However, to be accepted by Xcode, the `CARWatch.xcodeproj` might need to be moved to the parent directory (arbitrary name, e.g., CARWatchApp), yielding the following structure:

```bash
└── CARWatchApp
    ├── CARWatch.xcodeproj
    └── CARWatch
        ├── .git
        ├── CarWatchApp.swift
        ├── Assets.xcassets
        └── Different feature folders
```

### Framework
This App was written in Swift using the SwiftUI framework, which is the relatively new (2019) successor of UIKit. In contrast to the latter and the native CARWatch Android app, this framework uses a declarative approach and therefore differentiates fundamentally from the structure of the android app. The fundamental idea of declarative frameworks is to define user-facing views depending on states. Everytime a states changes, the UI components are then re-rendered automatically by the framework.

### Project Structure
This project follows the MVVM (model - view - view model) pattern to separate the frontend (view) from the data (model). The view model is the interfacing component between them, providing the data to the frontend.

The implemented models conform to the `Codable` protocol (in other words: they implement the `Codable` interface) to enable encoding and decoding them to and from JSON.

The implemented Views conform to the `View` Protocol, which is mandatory for every UI component in SwiftUI. Every view must have a computed property `body` that returns a View-Object consisting of UI elements such as `VStack` or `HStack`. Furthermore, in every view a `#Preview` macro can be defined that renders a preview of the UI slide directly in XCode (to see the preview, activate 'Canvas' in the editor options in the upper right corner).

The implemented view models conform to the `ObservableObject` protocol. This allows adding the `@Published` decorator to its properties, which notifies views that instantiating the view model when these properties are about to change. Based on this notification, the views will be updated. Once instantiated and provided by calling `.environmentObject(_:)` in an ancestor view, the view models and their data can be accessed in all descendant views of an app using the `@EnvironmentObject` decorator.

For further structuring, the code is separated by the distinct functions of the app:
- Onboarding: Study configuration and tutorial
- HomeScreen: Main screen slides & Menu bar
- Alarm: Scheduling sample reminders
- Permissions: Notification & Camera permission handling
- Scanner: Barcode & QR code scanning
- Utilities: Frequently reused functions, constants, event logger

Further files and directories of interest: 
- `CARWatchApp.swift`: entry point of the app where all view models are initialized
- `Assets.xcassets`: contains app logo and custom images, note: built-in icons can be searched and selected using the 'SF Symbols' app
- Resources: contains ringtone for incoming notifications and string translations (`Localizable.xcstrings`)

### Data Storage
Data that needs to be persisted in the CARWatch app consists of:
- session data (current state of the user, e.g., registration, tutorial slides, or ongoing study) -> `SessionDataViewModel`
- permission data -> `PermissionDataViewModel`
- study data (data retrieved from the study QR code) -> `StudyDataViewModel`
- alarm data (when each sample is due and whether they were already taken) -> `AlarmDataViewModel`

As the amounts of stored data are rather small for all view models, they are not stored in a database, but as `UserDefaults` (equivalent to shared preferences in Android)

### App Logic
The `currentState` variable in the session view model determines which UI view is displayed when launching the app. In `MainView`, based on that, the correct view is selected differentiating between onboarding and ongoing study.

#### Onboarding
The onboarding consists of two phases, the registration process (`RegistrationView`) and the tutorial slides (`TutorialView`).
During the registration process, the study data (from the QR code) is still unknown. This is the case when the app is (a) freshly installed or (b) the user hit the 'reregister' button in the main menu. 

In case (a), as first step of the registration process the permissions are requested. For each permission, the dialog can only be shown once; if the user denies, this decision can only be revoked by manually changing it in the app settings. As the core features of the CARWatch app are centered around scanning with the camera and receiving notifications, only a dummy slide (`MissingPermissionView`) linking to the app settings will be displayed until both permissions are granted. The app will fallback to this slide also if the user suddenly decides to revoke a permission manually.

Once the permissions are granted or in case (b), the user is prompted to scan the study qr code until a valid code is scanned. If the participant id is not included in the qr code, it has to be entered manually next. 

When this is done, the tutorial view is shown. This includes several explanation slides that can be either swept through or skipped directly. 

#### Ongoing Study
After the onboarding is done, the `OngoingStudyView` is displayed, which is a TabView consisting of three tabs: the `WakeupView`, the `AlarmView`, and the `BedtimeView`. 
In the wakeup tab, the user can enter a spontaneous awakening before the scheduled alarm time. This updates the schduled alarm time to the current time and starts the sampling procedure.

In the bedtime tab, the user can enter when going to bed. If in the study configuration an evening sample was specified, this will open the `ScannerView` to scan the barcode from the evening salivette.

The most complex logic lies in the `AlarmViewModel` behind the `AlarmView`. As iOS does not provide a public API for scheduling alarms, it uses local notifications handled by the `NotificationManager` singleton instead. Every sample is represented by an alarm from the `Alarm` model. All alarms that require a reminder are stored in the `timedAlarms` property of the alarm view model in chronological order. As soon as this property is modified, new reminders are scheduled for every alarm in the form of calendar based local notifications. Additionally, several backup notifications (amount defined by `NotificationConstants.numberOfSubsequentNotifications`) are scheduled for every sample in case the original notification is ignored or missed. The time interval between the backup notifications is defined by `NotificationConstants.minutesBetweenNotifications`. Using an extension of the  `AppDelegate`, it is detected when a notification is tapped by the user. This results in an execution of the `updateAlarmStatus` function in the alarm view model. It compares the current time with the scheduled alarm times and sets all alarms that are in the past, but not yet marked as scanned, as triggered.

Note that currently it is not checked which notification caused by which sample was opened by the user. Instead, the samples that are due will be processed and scanned in chronological order. Consequently, the barcode scanner will be opened to scan the next due alarm in chronological order when the user tapped on a sample reminder notification. After a successful barcode scan, the alarm will be set as scanned and therefore as finalized.

UI-wise, as soon as the initial alarm was triggered, its date picker and activity toggle will be set as disabled. The same applies for activity toggles of alarms that were already scanned on the current day. They will be re-enabled as soon as `isDayFinished` returns true (all active alarms of that day were scanned), except if the current day was the last day of the study (`isStudyFinished` returns true).

If the current day is finished, the `timedAlarms` array will be re-initialized using the same times, but the upcoming day using the `resetAlarmData` function. This will also cause the notifications to be rescheduled for the updated times, meaning that as long as one day is not finished, no new reminders will be scheduled for upcoming study days. 

#### Event Logging

Important events are written to `.csv` log files analogously to the android app. Creating and writing to the correct files is handled by the `Logger` class, whereas all data is written to the `Documents/carwatchLogs` directory of the app's home folder.

To share the logs, the share button in the main toolbar menu needs to be pressed. This triggers the creation of a zip file from all logs present in the log directory. To simplify the zipping, the external library [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) is used. 

As UI, a sheet is displayed on top of the current view. SwiftUI has a build-in solution for share dialogs (`ShareLink`), however it was only introduced in iOS 16. To support older devices, a `MFMailComposeViewController` from UIKit was used and bound to a SwiftUI view using the `UIViewControllerRepresentable` protocol. This directly opens the apple mail app and setting a recipient and attachment. However, it will only open if the user is actively using the apple mail app and has at least one account added there. Therefore, a `UIActivityViewController` i used as fallback providing a wide range of sharing options. Unfortunately, when a mail app is selected, the recipient can not be set programmatically here.

#### BarcodeScanner

SwiftUI does not have a built-in code scanner component (yet), thats why a custom `CodeScanner` was implemented. This scanner is a simplified version of [this project](https://github.com/twostraws/CodeScanner) supporting EAN8 and QR codes. Additionally, a `rectOfInterest` was added to the scanner aligning with the `ScannerOverlay` UI component.
If debugging is required, the scanner's area of interest can be visualized in the `addRectOfInterest` function.

### Short comparison CARWATCH Android vs. iOS

### Helpful hacks and resources 
- when building fails without any obvious reason, (force) cleaning the build folder can help: `(Option) + Command + Shift + K`
- change language of XCode preview: Product -> Scheme -> Edit -> Options -> App language
- use SF Symbols app for finding icons
- use `.border(Color.black, width: 5)` for debugging UI elements
- nice introduction to SwiftUI: https://developer.apple.com/tutorials/develop-in-swift/welcome-to-develop-in-swift-tutorials (note that many features shown there are not available for older iOS versions)
- nice tutorial series to understand MVVM: https://www.youtube.com/playlist?list=PLwvDm4VfkdpheGqemblOIA7v3oq0MS30i
- very helpful youtube channels with tutorials on everything Swift-related: https://www.youtube.com/@twostraws/featured
