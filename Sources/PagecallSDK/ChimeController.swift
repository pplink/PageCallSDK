//
//  ChimeController.swift
//
//
//  Created by 록셉 on 2022/07/27.
//

import AmazonChimeSDK
import AVFoundation
import Foundation

class ChimeController {
    var meetingSession: DefaultMeetingSession?
    let emitter: WebViewEmitter

    init(emitter: WebViewEmitter) {
        self.emitter = emitter

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("granted")
            } else {
                print("rejected")
            }
        }
    }

    func connect(joinMeetingData: Data, callback: ((Bool) -> Void)? = nil) {
        let logger = ConsoleLogger(name: "DefaultMeetingSession", level: LogLevel.INFO)

        let meetingSessionConfiguration = JoinRequestService.getMeetingSessionConfiguration(data: joinMeetingData)

        guard let meetingSessionConfiguration = meetingSessionConfiguration else {
            logger.error(msg: "Failed to parse meetingSessionConfiguration")
            callback?(false)
            return
        }

        let meetingSession = DefaultMeetingSession(configuration: meetingSessionConfiguration, logger: logger)
        self.meetingSession = meetingSession

        meetingSession.audioVideo.addRealtimeObserver(observer: ChimeRealtimeObserver(emitter: self.emitter, myAttendeeId: meetingSession.configuration.credentials.attendeeId))

        do { try meetingSession.audioVideo.start()
            print("succeed")
            callback?(true)
        } catch {
            print(error)
            callback?(false)
        }
    }

    func pauseAudio(callback: ((Bool) -> Void)? = nil) {
        let isSucceed = self.meetingSession?.audioVideo.realtimeLocalMute() ?? false
        callback?(isSucceed)
    }

    func resumeAudio(callback: ((Bool) -> Void)? = nil) {
        let isSucceed = self.meetingSession?.audioVideo.realtimeLocalUnmute() ?? false
        callback?(isSucceed)
    }

    func setAudioDevice(deviceData: Data, callback: ((Bool) -> Void)? = nil) {
        let jsonDecoder = JSONDecoder()
        struct DeviceId: Codable {
            var deviceId: String
        }

        let deviceId = try? jsonDecoder.decode(DeviceId.self, from: deviceData)

        guard let meetingSession = self.meetingSession else {
            print("failed to setAudioDevice: meetingSession not exist")
            callback?(false)
            return
        }

        let audioDevices = meetingSession.audioVideo.listAudioDevices()

        let audioDevice = audioDevices.first { mediaDevice in mediaDevice.label == deviceId?.deviceId }
        guard let audioDevice = audioDevice else {
            print("failed to find mediaDevice with label")
            callback?(false)
            return
        }

        meetingSession.audioVideo.chooseAudioDevice(mediaDevice: audioDevice)
        callback?(true)
    }

    func getAudioDevices(callback: ([MediaDeviceInfo]) -> Void) {
        let audioDevices = self.meetingSession?.audioVideo.listAudioDevices()

        guard let audioDevices = audioDevices else {
            callback([])
            return
        }

        let audioDeviceInfoList = audioDevices.map { mediaDevice in
            MediaDeviceInfo(deviceId: mediaDevice.label, groupId: "DefaultGroupId", kind: .audioinput, label: mediaDevice.label)
        }

        callback(audioDeviceInfoList)
    }
}
