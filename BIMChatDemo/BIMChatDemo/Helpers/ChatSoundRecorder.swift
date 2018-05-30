//
//  ChatSoundRecorder.swift
//  AirTalk
//
//  Created by GavinWinner on 2018/3/6.
//  Copyright © 2018年 边智峰. All rights reserved.
//

import UIKit
import AVKit

enum ChatRecorderState: Int {
    case Stop
    case Recording
    case RelaseCancel
    case CountDown
    case MaxRecord
    case TooShort
}

///  代理
protocol ChatSoundRecorderDelegate: NSObjectProtocol {
    
    func onChatWillSendMsg(msg: IMChatMsg?)
    func onChatCancelSendMsg(msg: IMChatMsg?)
    func onChatReplaceSendMsg(msg: IMChatMsg?)
}

typealias UpdateTimeBlock = (_ time: Int) -> ()
typealias RecordFinishedBlock = () -> ()
class ChatSoundRecorder: NSObject {

    var session: AVAudioSession?
    var recorder: AVAudioRecorder?
    var recordSavePath: String?
    var recorderPeakerTimer: Timer?
    var recorderTimer: Timer?
    var recordPeak: Int? = 1
    var recordDuration: Int = 0
    var recordState: ChatRecorderState?
    weak var recorder_delegate: ChatSoundRecorderDelegate?
    var recordingMsg: IMChatMsg?
    //原始音频类别
    var audioSessionCategory: String?
    //原始音频模式
    var audioSessionMode: String?
    //原始音频类别选项
    var audioSessionCategoryOptions: AVAudioSessionCategoryOptions?
    var updateTimeBlock : UpdateTimeBlock?
    var recordFinishedBlock: RecordFinishedBlock?
    var chatVoiceCell: ChatTableViewCell?
    
    public static let sharedInstance = ChatSoundRecorder()
    private override init() {
        super.init()
        activeAudioSession()
        NIMSDK.shared().mediaManager.add(self)
    }
    
    class func destory() {
        sharedInstance.recordState = ChatRecorderState.RelaseCancel
        sharedInstance.stopRecord()
        sharedInstance.recorder = nil
    }

    /// 开启始终以扬声器模式播放声音
    func activeAudioSession() {
        session = AVAudioSession.sharedInstance()
        do {
            try session?.setCategory(AVAudioSessionCategoryPlayAndRecord)
            audioSessionCategory = session?.category
            audioSessionMode = session?.mode
            audioSessionCategoryOptions = session?.categoryOptions
        
            do {
                try session?.overrideOutputAudioPort(AVAudioSessionPortOverride.speaker)
                do {
                    try session?.setActive(true)
                } catch {
                    print(error)
                    return
                }
            } catch {
                print(error)
                return
            }
        } catch {
            print(error)
            return
        }
    }
    
    func initRecord() -> Bool {

        let recordSetting = [AVSampleRateKey : NSNumber(value: Float(44100.0)),//声音采样率
            AVFormatIDKey : NSNumber(value: Int32(kAudioFormatMPEG4AAC)),//编码格式
            AVNumberOfChannelsKey : NSNumber(value: 1),//采集音轨
            AVLinearPCMBitDepthKey: NSNumber(value: 16),//线性采样位数
            AVEncoderAudioQualityKey : NSNumber(value: Int32(AVAudioQuality.high.rawValue))]//音频质量
        
        let fileUrlString = "\(NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last ?? "")/\(GetUuid()).caf"

        let fileUrl = URL(fileURLWithPath: fileUrlString)
        
        recordSavePath = fileUrlString

        do {
            recorder = try AVAudioRecorder(url: fileUrl, settings: recordSetting)
            if recorder != nil {
                recorder?.isMeteringEnabled = true
                if recorder?.prepareToRecord() == true {
                    return true
                }
            }
        } catch {
            print("录音初始化失败 \(error)")
            return false
        }
        print("录音初始化失败")
        return false
    }
    
    func startRecord() {
        
        if NIMSDK.shared().mediaManager.isPlaying() == true {
            NIMSDK.shared().mediaManager.stopPlay()
            chatVoiceCell?.startOrStopVoiceAnimation(start: false)
            chatVoiceCell = nil
        }
        
        let avSession = AVAudioSession.sharedInstance()
        avSession.requestRecordPermission { (available) in
            if available == false {
                print("无法录音, 请在“设置-隐私-麦克风”中允许访问麦克风。")
                DispatchQueue.main.async {
                    
                }
            } else {
                DispatchQueue.main.async {
                    self.startRecording()
                }
            }
        }
    }
    
    func startRecording() {
        
        if recordState == ChatRecorderState.TooShort {
            return
        }
        recorder?.stop()
        
        if initRecord() == false {
            
            return
        }
        print("开始录音")
        recorder?.record()
        
        recordPeak = 1
        recordDuration = 0
        recordState = ChatRecorderState.Recording
        
        recorderTimer = Timer(timeInterval: 1, target: self, selector: #selector(onRecording), userInfo: nil, repeats: true)
        if recorderTimer != nil {
            RunLoop.current.add(recorderTimer!, forMode: RunLoopMode.commonModes)
        }
        
//        recorderPeakerTimer = Timer(timeInterval: 0.2, target: self, selector: #selector(onRecordPeak), userInfo: nil, repeats: true)
//        if recorderPeakerTimer != nil {
//            RunLoop.current.add(recorderPeakerTimer!, forMode: RunLoopMode.commonModes)
//        }
    }
    
    @objc func onRecordPeak() {
        recorder?.updateMeters()
        print("声音监听")
        var peakPower: Float = 0
        peakPower = (recorder?.peakPower(forChannel: 0)) ?? 0
        peakPower = pow(10, 0.05 * peakPower)
        
        var peak: Int = Int((peakPower * 100) / 20 + 1)
        if peak < 1 {
            peak = 1
        } else if peak > 5 {
            peak = 5
        }
        if peak != recordPeak {
            recordPeak = peak
        }
    }
    
    @objc func onRecording() {
        recordDuration += 1
        if let block = updateTimeBlock {
            block(recordDuration)
        }
        print("录音中")
        if recordDuration == 60 {
            recorderTimer?.invalidate()
            recorderTimer = nil
            
            recorderPeakerTimer?.invalidate()
            recorderPeakerTimer = nil
            
            recordState = ChatRecorderState.MaxRecord
            
            stopRecord()
        } else if recordDuration >= 59 {
            recordState = ChatRecorderState.CountDown
        } else if recordDuration == 1 {
            //预添加语音消息到界面
            recordingMsg = IMChatMsg.msgWithEmptySound()
            recorder_delegate?.onChatWillSendMsg(msg: recordingMsg)
        }
    }
    
    func willCancelRecord() {
        print("将要结束录音")
        if recordDuration > 59 {
            recordState = ChatRecorderState.CountDown
        } else {
            recordState = ChatRecorderState.RelaseCancel
        }
    }
    
    func continueRecord() {
        print("录音中--")
        if recordDuration > 59 {
            recordState = ChatRecorderState.CountDown
        } else {
            recordState = ChatRecorderState.Recording
        }
    }
    
    func stopRecord() {
        recorderTimer?.invalidate()
        recorderTimer = nil
        
        recorderPeakerTimer?.invalidate()
        recorderPeakerTimer = nil
        
        if recorder?.isRecording == false {
            return
        }
        print("结束录音")
        let duration = recorder?.currentTime
        
        if let block = recordFinishedBlock {
            block()
        }
        
        if recordState == ChatRecorderState.RelaseCancel {
            recordState = ChatRecorderState.Stop
            
            recorder_delegate?.onChatCancelSendMsg(msg: recordingMsg)
            return
        }
        
        recorder?.stop()
        
        if (duration ?? 0) < 0.5 {
            recordState = ChatRecorderState.TooShort
        } else {
            recorder?.stop()
            if recordSavePath == nil {
                print("录音失败")
                return
            }
        
            let audioData = NSData(contentsOfFile: recordSavePath!)
            
            //整数秒
            let dur = Int(duration! + 0.5)
            
            let finalMsg = IMChatMsg.msgWithSound(data: audioData, duration: dur)
            
            recorder_delegate?.onChatReplaceSendMsg(msg: finalMsg)
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
            self.recordState = ChatRecorderState.Stop
        }

        if FileManager.default.fileExists(atPath: recorder?.url.path ?? "") == true {
            if recorder?.isRecording == true {
                recorder?.deleteRecording()
            }
        }
    }
    
    
    /// 播放语音
    ///
    /// - Parameters:
    ///   - withMsg: msg
    ///   - lastCell: cell
    func playOrStopMediaAudio(withMsg: IMChatMsg, lastCell: ChatTableViewCell?) {
        chatVoiceCell?.startOrStopVoiceAnimation(start: false)
        if NIMSDK.shared().mediaManager.isPlaying() == false {
            lastCell?.startOrStopVoiceAnimation(start: true)
            chatVoiceCell = lastCell
            NIMSDK.shared().mediaManager.switch(NIMAudioOutputDevice.speaker)
            NIMSDK.shared().mediaManager.play((withMsg.msg?.messageObject as! NIMAudioObject).path!)
        } else {
            chatVoiceCell = nil
            NIMSDK.shared().mediaManager.stopPlay()
        }
    }

}

