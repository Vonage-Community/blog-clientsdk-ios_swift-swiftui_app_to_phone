//
//  ContentView.swift
//  SwiftUICall
//
//  Created by Abdulhakim Ajetunmobi on 30/10/2020.
//

import SwiftUI
import AVFoundation
import VonageClientSDKVoice

struct ContentView: View {
    @ObservedObject var callModel = CallModel()
    
    var body: some View {
        VStack {
            Text(callModel.status)
            
            if self.callModel.status == "Connected" {
                TextField("Enter a phone number", text: $callModel.number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .disabled(self.callModel.isCalling)
                    .padding(20)
                
                if !self.callModel.isCalling {
                    Button(action: { self.callModel.callNumber() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone")
                            Text("Call")
                        }
                    }
                }
                
                if self.callModel.isCalling {
                    Button(action: { self.callModel.endCall() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "phone")
                            Text("End Call")
                        }.foregroundColor(Color.red)
                    }
                }
            }
        }
        .animation(.default)
        .onAppear(perform: self.callModel.setup)
    }
}

final class CallModel: NSObject, ObservableObject, VGVoiceClientDelegate {
    
    @Published var status: String = ""
    @Published var isCalling: Bool = false
    let client = VGVoiceClient()
    var number: String = ""
    
    private var callId: String?
    private let audioSession = AVAudioSession.sharedInstance()
    
    func setup() {
        initializeClient()
        requestPermissionsIfNeeded()
        loginIfNeeded()
    }
    
    func initializeClient() {
        let config = VGClientConfig(region: .US)
        client.setConfig(config)
        client.delegate = self
    }
    
    func requestPermissionsIfNeeded() {
        if audioSession.recordPermission != .granted {
            audioSession.requestRecordPermission { (isGranted) in
                print("Microphone permissions \(isGranted)")
            }
        }
    }
    
    func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.status = text
        }
    }
    
    func resetState() {
        DispatchQueue.main.async {
            self.callId = nil
            self.isCalling = false
            self.number = ""
        }
    }
    
    func loginIfNeeded() {
        guard status != "Connected" else { return }
        VGVoiceClient.isUsingCallKit = false
        client.createSession("ALICE_JWT") { error, sessionId in
            if let error {
                self.updateStatus(error.localizedDescription)
            } else {
                self.updateStatus("Connected")
            }
        }
    }
    
    func callNumber() {
        self.isCalling = true
        client.serverCall(["to": number]) { error, callId in
            if error == nil {
                self.callId = callId
            }
        }
    }
    
    func endCall() {
        client.hangup(callId!) { error in
            if error == nil {
                self.resetState()
            }
        }
    }
    
    func voiceClient(_ client: VGVoiceClient, didReceiveHangupForCall callId: VGCallId, withQuality callQuality: VGRTCQuality, reason: VGHangupReason) {
        self.resetState()
    }
    
    func client(_ client: VGBaseClient, didReceiveSessionErrorWith reason: VGSessionErrorReason) {
        let reasonString: String!
        
        switch reason {
        case .tokenExpired:
            reasonString = "Expired Token"
        case .pingTimeout, .transportClosed:
            reasonString = "Network Error"
        default:
            reasonString = "Unknown"
        }
        
        status = reasonString
    }
    
    func voiceClient(_ client: VGVoiceClient, didReceiveInviteForCall callId: VGCallId, from caller: String, with type: VGVoiceChannelType) {}
    func voiceClient(_ client: VGVoiceClient, didReceiveInviteCancelForCall callId: VGCallId, with reason: VGVoiceInviteCancelReason) {}
}
