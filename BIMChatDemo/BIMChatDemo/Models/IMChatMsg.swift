//
//  IMChatMsg.swift
//  AirTalk
//
//  Created by GavinWinner on 2018/3/6.
//  Copyright © 2018年 边智峰. All rights reserved.
//

import UIKit
import NIMSDK
import NIMAVChat
enum IMChatMsgStatus: Int {
    case Init //初始化
    case WillSending //即将发送
    case Sending //发送中
    case SendSucc //发送成功
    case SendFail //发送失败
}

class IMChatMsg: NSObject {

    var msg: NIMMessage?
    var type: NIMMessageType?
    var status: IMChatMsgStatus?
    
    convenience init(iMsg: NIMMessage, iType: NIMMessageType) {
        self.init()
        msg = iMsg
        type = iType
        status = IMChatMsgStatus.WillSending
        switch iMsg.deliveryState {
            case .deliveried:
                //成功
                status = IMChatMsgStatus.SendSucc
                break
            case .delivering:
            //发送中
                status = IMChatMsgStatus.Sending
                break
            case .failed:
            //失败
                status = IMChatMsgStatus.SendFail
                break
        }
        
    }
    
    /// 语音消息
    ///
    /// - Parameters:
    ///   - data: 录音数据
    ///   - duration: 录音时长
    /// - Returns: IMChatMsg
    class func msgWithSound(data: NSData?, duration: Int) -> IMChatMsg? {
        if data == nil {
            return nil
        }
        
        let cache = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).last
        
        let time = "\(NSDate().timeIntervalSince1970)"
        let soundSaveDir = "\(cache ?? "")/Audio"
        
        if IMChatMsg.isExistFile(fileName: soundSaveDir) == false {
            do {
               try FileManager.default.createDirectory(atPath: soundSaveDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        
        let soundSavePath = "\(soundSaveDir)/\(time)"
        if IMChatMsg.isExistFile(fileName: soundSavePath) == false {
            do {
                try FileManager.default.createDirectory(atPath: soundSaveDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return nil
            }
        }
        
        let isWrite = data?.write(toFile: soundSavePath, atomically: true)
        if isWrite == false {
            return nil
        }
        let message = NIMMessage()
        let sound = NIMAudioObject(sourcePath: soundSavePath)
        sound.duration = duration
        message.messageObject = sound
        return IMChatMsg(iMsg: message, iType: NIMMessageType.audio)
    }
    
    /// 创建一个空白的语音 用来待发送状态显示
    ///
    /// - Returns: IMChatMsg
    class func msgWithEmptySound() -> IMChatMsg {
        let message = NIMMessage()
        message.messageObject = NIMAudioObject()
        return IMChatMsg(iMsg: message, iType: NIMMessageType.audio)
    }
    
    /// 图片消息
    ///
    /// - Parameter withImage: 要发送的图片
    /// - Returns: IMChatMsg
    class func msgWithImage(withImage: UIImage) -> IMChatMsg {
        let message = NIMMessage()
        message.messageObject = NIMImageObject(image: withImage)
        return IMChatMsg(iMsg: message, iType: NIMMessageType.image)
    }
    
    /// 时间戳
    ///
    /// - Parameter timeInterval: 消息发送时间戳
    /// - Returns: IMChatMsg
    class func msgWithTimesamp(timeInterval: TimeInterval) -> IMChatMsg {
        let message = NIMMessage()
        message.timestamp = timeInterval
        message.messageObject = NIMCustomObject()
        return IMChatMsg(iMsg: message, iType: NIMMessageType.custom)
    }
    
    class func isExistFile(fileName: String?) -> Bool {
        if fileName == nil || fileName == "" {
            return false
        }
        let filePath = IMChatMsg.getFileResourcePath(filePath: fileName)
        if filePath == nil {
            return false
        }
        
        return FileManager.default.fileExists(atPath: filePath!)
    }
    
    class func getFileResourcePath(filePath: String?) -> String? {
        if filePath == nil || filePath == "" {
            return nil
        }
        
        let resourceDir = Bundle().resourcePath
        return resourceDir?.appending(filePath!)
        
    }
    
    /// 文字消息
    ///
    /// - Parameter withText: 要发送的文字
    /// - Returns: IMChatMsg
    class func msgWithText(withText: String) -> IMChatMsg {
        let message = NIMMessage()
        message.text = withText
        return IMChatMsg(iMsg: message, iType: NIMMessageType.text)
    }
}
