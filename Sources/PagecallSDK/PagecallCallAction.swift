import CallKit
import AVKit

public class PagecallCallAction: NSObject, CXProviderDelegate {
    public func providerDidReset(_ provider: CXProvider) {
        print("PagecallCallAction: providerDidReset")
    }
    
    public func providerDidBegin(_ provider: CXProvider) {
        print("PagecallCallAction: providerDidReset")
    }
    
    public func provider(_ provider: CXProvider, execute transaction: CXTransaction) -> Bool {
        print("PagecallCallAction: execute transaction")
        return false
    }
    
    public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("PagecallCallAction: perform startCall")
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("PagecallCallAction: perform endCall")
        action.fulfill()
    }
    
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
       print("PagecallCallAction: didActivateAudioSession")
    }
    
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
       print("PagecallCallAction: didDeactivateAudioSession")
    }
    
    static private var shared: PagecallCallAction?
    
    let uuid = UUID()
    private let localizedName: String
    private var provider: CXProvider {
        get {
            var configuration: CXProviderConfiguration?
            if #available(iOS 14.0, *) {
                configuration = CXProviderConfiguration()
            } else {
                configuration = CXProviderConfiguration(localizedName: localizedName)
            }
            configuration!.supportedHandleTypes = [.generic]
            let provider = CXProvider(configuration: configuration!)
            return provider
        }
    }
    private let callController = CXCallController(queue: .main)
    
    init(localizedName: String) {
        self.localizedName = localizedName;
    }
    
    private func start() {
        self.provider.setDelegate(self, queue: nil)
        let handle = CXHandle(type: .generic, value: localizedName)
        let startCallAction = CXStartCallAction(call: uuid, handle: handle)
        callController.requestTransaction(with: startCallAction) { error in
            if let error = error {
                print("PagecallCallAction: error starting call action", error)
            } else {
                print("PagecallCallAction: successfully started call action")
                self.provider.reportOutgoingCall(with: self.uuid, connectedAt: Date())
            }
        }
    }
    
    private func end() {
        let endCallAction = CXEndCallAction(call: uuid)
        callController.requestTransaction(with: endCallAction) { error in
            if let error = error {
                print("PagecallCallAction: error ending call action", error)
            } else {
                print("PagecallCallAction: successfully ended call action")
            }
        }
    }
    
    public static func enable(localizedName: String) -> Bool {
        if let _ = shared {
            return false
        } else {
            let shared = PagecallCallAction(localizedName: localizedName)
            shared.start()
            PagecallCallAction.shared = shared
            return true
        }
    }
    
    public static func disable() -> Bool {
        if let shared = shared {
            shared.end()
            PagecallCallAction.shared = nil
            return true
        } else {
            return false
        }
    }
}
