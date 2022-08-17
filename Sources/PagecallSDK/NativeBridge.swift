//
//  NativeBridge.swift
//
//
//  Created by 록셉 on 2022/07/26.
//

import Foundation
import WebKit

enum BridgeEvent: String, Codable {
    case audioDevices, audioVolume, audioStatus, mediaStat, audioEnded, videoEnded, screenshareEnded, meetingEnded, error
}

class WebViewEmitter {
    let webview: WKWebView

    func emit(eventName: BridgeEvent) {
        self.webview.evaluateJavaScript("window.PagecallNative.emit('\(eventName)')") { _, error in
            if let error = error {
                NSLog("Failed to PagecallNative.emit \(error)")
            }
        }
    }

    func emit(eventName: BridgeEvent, message: String) {
        self.webview.evaluateJavaScript("window.PagecallNative.emit('\(eventName)','\(message)')") { _, error in
            if let error = error {
                NSLog("Failed to PagecallNative.emit \(error)")
            }
        }
    }

    func emit(eventName: BridgeEvent, data: Data) {
        if let string = String(data: data, encoding: .utf8) {
            self.emit(eventName: eventName, message: string)
        }
    }

    init(webView: WKWebView) {
        self.webview = webView
    }
}

class NativeBridge {
    let webview: WKWebView
    let emitter: WebViewEmitter
    let ChimeController: ChimeController

    init(webview: WKWebView) {
        self.webview = webview
        self.emitter = .init(webView: self.webview)
        self.ChimeController = .init(emitter: self.emitter)
    }

    func response(requestId: String?) {
        guard let requestId = requestId else {
            return
        }

        self.webview.evaluateJavaScript("window.PagecallNative.response('\(requestId)')") { _, error in
            if let error = error {
                NSLog("Failed to PagecallNative.response \(error)")
            }
        }
    }

    func response(requestId: String?, data: Data) {
        guard let requestId = requestId else {
            return
        }

        let string = String(data: data, encoding: .utf8)
        if let string = string {
            self.webview.evaluateJavaScript("window.PagecallNative.response('\(requestId)','\(string)')") { _, error in
                if let error = error {
                    NSLog("Failed to PagecallNative.response \(error)")
                }
            }
        }
    }

    func messageHandler(message: String) {
        do {
            let data = message.data(using: .utf8)!
            guard let jsonArray = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            else {
                NSLog("Failed to JSONSerialization")
                return
            }
            guard let action = jsonArray["action"] as? String, let requestId = jsonArray["requestId"] as? String?, let payload = jsonArray["payload"] as? String? else {
                return
            }

            switch action {
            case "connect":
                print("Bridge: connect")
                if let payloadData = payload?.data(using: .utf8) {
                    self.ChimeController.connect(joinMeetingData: payloadData) { (_: Bool) in self.response(requestId: requestId) }
                }
            case "pauseAudio":
                print("Bridge: pauseAudio")
                self.ChimeController.pauseAudio()
            case "resumeAudio":
                print("Bridge: resumeAudio")
                self.ChimeController.resumeAudio()
            case "setAudioDevice":
                print("Bridge: setAudioDevice")
                if let payloadData = payload?.data(using: .utf8) {
                    self.ChimeController.setAudioDevice(deviceData: payloadData) { (isGood: Bool) in print(isGood) }
                }

            case "getAudioDevices":
                print("Bridge: getAudioDevices")
                self.ChimeController.getAudioDevices {
                    (mediaDeviceInfoList: [MediaDeviceInfo]) in do {
                            let data = try JSONEncoder().encode(mediaDeviceInfoList)
                            self.response(requestId: requestId, data: data)
                        } catch {
                            print("failed to getAudioDevices")
                        }
                }
            default:
                break
            }
        } catch let error as NSError {
            print(error)
        }
    }
}
