//
//  ChatManager.swift
//  AirTalk
//
//  Created by GavinWinner on 2018/3/8.
//  Copyright © 2018年 边智峰. All rights reserved.
//

import UIKit
import NIMSDK
import NIMAVChat

typealias RecvMsgBlock = (_ msgs: [IMChatMsg]) -> ()
typealias RecvAudioBlock = (_ controller: UIViewController?) -> ()
typealias SendMsgBlock = (_ sendStatus: IMChatMsgStatus, _ sendMsgId: String) -> ()
class ChatManager: NSObject {

    @objc var recvMsgBlock : RecvMsgBlock?
    var sendMsgBlock : SendMsgBlock?
    @objc var recvMsgNoSessionBlock : RecvMsgBlock? //无聊天时 通知主页有新消息通知更新会话列表
    var recvAudioBlock : RecvAudioBlock?
    var lastMsg: NIMMessage?
    var currentSession: NIMSession?
    
    @objc public static let sharedInstance = ChatManager()
    private override init() {
        super.init()

        initNIM()
    }
    
    fileprivate func initNIM() {
        let option = NIMSDKOption(appKey: "162a2d6f10d02c538c90dfbe70b528c8")
        
        NIMSDK.shared().register(with: option)
        NIMSDK.shared().loginManager.add(self)
        NIMSDK.shared().chatManager.add(self)
        NIMAVChatSDK.shared().netCallManager.add(self)
    }
    
    @objc func login(withAccount: String?, Token: String?) {
        guard let user = ATUserModel.userModelGetLoginSuccessResult(),
              let userDetail = user.user,
              let account = withAccount,
              let token = Token
              else { return }
        DispatchQueue.global().async {
            let login = NIMAutoLoginData()
            login.account = account
            login.token = token
            if let cloudToken = userDetail.cloudToken {
                login.token = cloudToken
            } else {
                
            }
            
            NIMSDK.shared().loginManager.login(account, token: login.token, completion: { (error) in
                if error != nil {
                    print("手动登录失败 \(error!)")
                }
            })
        }
    }
    
    @objc func deleteConversation(withConversation: NIMRecentSession) {
        NIMSDK.shared().conversationManager.delete(withConversation)
        if let session = withConversation.session {
            NIMSDK.shared().conversationManager.deleteAllmessages(in: session, option: nil)
        }
    }
    
    @objc func getConversationList(withCompltion: @escaping (_ sessions: [NIMRecentSession]?) -> ()) {
        let conversations = NIMSDK.shared().conversationManager.allRecentSessions()
        let friends = DBManager.shared.getAllFriends(withTableName: friendsDB)
        if (conversations?.count ?? 0) > 0 && (friends?.count ?? 0) == 0 {
            FriendViewModel().onlyfindFriendFromServer(finished: { (success, error) in
                withCompltion(conversations)
            })
        } else {
            withCompltion(conversations)
        }
    }
    
    func getAndDeleteRecentSession(withSessionId: String) {
        let session = NIMSession(withSessionId, type: .P2P)
        if let recentSession = NIMSDK.shared().conversationManager.recentSession(by: session) {
            deleteConversation(withConversation: recentSession)
        }
    }
    
    func getAnyConversationMessage(withSession: NIMSession, message: IMChatMsg?, limit: Int? = 20) -> [IMChatMsg] {
        if let messages = NIMSDK.shared().conversationManager.messages(in: withSession, message: message?.msg, limit: limit ?? 20) {
            return onLoadRecentMessageSuccess(withArray: messages)
        } else {
            return [IMChatMsg]()
        }
    }
    
    fileprivate func onLoadRecentMessageSuccess(withArray: [NIMMessage]) -> [IMChatMsg] {
        lastMsg = withArray.last
        
        var msgs = [IMChatMsg]()
        
        if withArray.count > 0 {
  
            var idx = 0
            
            var tempMsg: NIMMessage? = nil
            
            repeat {
                let msg = withArray[idx]

                if idx == 0 {
                    let timeTip = IMChatMsg.msgWithTimesamp(timeInterval: msg.timestamp)
                    msgs.append(timeTip)
                }
                
                if tempMsg != nil {
                    let nextDate = Date(timeIntervalSince1970: msg.timestamp)
                    let lastDate = Date(timeIntervalSince1970: (tempMsg?.timestamp)!)
                    print("next == \(nextDate) last == \(lastDate)")
                    let timeinterval = nextDate.timeIntervalSince(lastDate)

                    if timeinterval > 300 {
                        //大于五分钟
                        let timeTip = IMChatMsg.msgWithTimesamp(timeInterval: msg.timestamp)
                        msgs.append(timeTip)
                    }
                }
                
                tempMsg = msg
                
                let chatMsg = IMChatMsg(iMsg: msg, iType: msg.messageType)
                msgs.append(chatMsg)
                
                idx += 1
            }
            while (idx < withArray.count)

            return msgs
            
        } else {
            return msgs
        }
    }
    
    func logout() {
        NIMSDK.shared().loginManager.logout { (error) in
            print("退出登录失败")
        }
    }
    
    func removeNIMDelegate() {
        NIMSDK.shared().chatManager.remove(self)
        NIMSDK.shared().loginManager.remove(self)
        NIMAVChatSDK.shared().netCallManager.remove(self)
    }
    
    class func sendMsg(withMsg: IMChatMsg?, lastMsg: IMChatMsg?, session: NIMSession?, chatModel: ChatModel?) {
        if withMsg?.msg != nil && session != nil {
            if let userModel = ATUserModel.userModelGetLoginSuccessResult(), let mineAvatar = userModel.user.avatarUrl, let mineName = userModel.user.nickname, let avatar = chatModel?.avatar, let name = chatModel?.name {
                withMsg?.msg?.remoteExt = ["reciverName": name, "reciverAvatar": avatar, "fromAvatar": mineAvatar, "fromName": mineName]
            }
            withMsg?.msg?.from = NIMSDK.shared().loginManager.currentAccount()
            do {
                try NIMSDK.shared().chatManager.send((withMsg?.msg)!, to: session!)
            } catch {
                print(error)
            }
        }
    }
    
    class func voiceViewContentSize(withCellWidth: CGFloat, message: NIMAudioObject) -> CGFloat {
        
        let value = CGFloat(2 * atan(Double(message.duration - 1) / 60.0) / Double.pi)
        let audioContentMinWidth = withCellWidth - 280
        let audioContentMaxWidth = withCellWidth - 170

        return (audioContentMaxWidth - audioContentMinWidth) * value + audioContentMinWidth

    }
    
    class func netcallNotificationFormatedMessage(message: NIMMessage?, finished: @escaping (_ netCallType: NIMNetCallType, _ string: String?) -> ()) {
        var string: String?
        let currentAccount = NIMSDK.shared().loginManager.currentAccount()
        
        
        if let obj = message?.messageObject as? NIMNotificationObject, let callParams = obj.content as? NIMNetCallNotificationContent {
            switch callParams.eventType {
                
            case .reject:
                string = "未接听"
                break
            case .noResponse:
                string = "未接通，已取消"
                break
            case .miss:
                string = obj.message?.from == currentAccount ? "对方正忙":"已拒绝"
                break
            case .bill:
                string = obj.message?.from == currentAccount ? "通话拨打时长 ":"通话接听时长 "
                let duration = callParams.duration
                let durationDesc = String(format: "%02d:%02d", arguments: [Int(duration) / 60, Int(duration) % 60])
                string = (string ?? "") + durationDesc
                break
            }
            
            finished(callParams.callType, string)
        }
    }
    
}

extension ChatManager: NIMChatManagerDelegate, NIMLoginManagerDelegate, NIMNetCallManagerDelegate {
    
    func willSend(_ message: NIMMessage) {
        guard let block = recvMsgBlock else { return }
        var msgs = [IMChatMsg]()
        if lastMsg?.timestamp != nil {
            let nextDate = Date(timeIntervalSince1970: message.timestamp)
            let lastDate = Date(timeIntervalSince1970: (lastMsg?.timestamp)!)
            let timeinterval = nextDate.timeIntervalSince(lastDate)
            
            if timeinterval > 300 {
                //大于五分钟
                let timeTip = IMChatMsg.msgWithTimesamp(timeInterval: message.timestamp)
                msgs.append(timeTip)
            }
        }
        print(message.messageId)
        msgs.append(IMChatMsg(iMsg: message, iType: message.messageType))
        lastMsg = msgs.last?.msg
        block(msgs)
    }
    
    func send(_ message: NIMMessage, didCompleteWithError error: Error?) {
        print("消息通知: \(message.messageId)")
        guard let block = sendMsgBlock else { return }
        block(message.deliveryState == .failed ? .SendFail:.SendSucc, message.messageId)
    }
    
    func onRecvMessages(_ messages: [NIMMessage]) {
        //设置最后一条消息
        if let msg = messages.last {
            if msg.session?.sessionId == currentSession?.sessionId && currentSession != nil {
                NIMSDK.shared().conversationManager.markAllMessagesRead(in: currentSession!)
                lastMsg = msg
            } else {
                if let block = recvMsgNoSessionBlock {
                    block([IMChatMsg(iMsg: msg, iType: msg.messageType)])
                }
                LocalNotificationManager.shared.PresentLocalNotification(msg: messages.last)
                return
            }
        }
        var msgs = [IMChatMsg]()
        for msg in messages {
            let chatMsg = IMChatMsg(iMsg: msg, iType: msg.messageType)

            switch msg.deliveryState {
            case .deliveried:
                chatMsg.status = IMChatMsgStatus.SendSucc
                break
            case .delivering:
                chatMsg.status = IMChatMsgStatus.Sending
                break
            case .failed:
                chatMsg.status = IMChatMsgStatus.SendFail
                break
            }
            msgs.append(chatMsg)
        }
        LocalNotificationManager.shared.PresentLocalNotification(msg: messages.last)
        guard let block = recvMsgBlock else { return }
        
        block(msgs)
    }
    
    func onReceive(_ callID: UInt64, from caller: String, type: NIMNetCallMediaType, message extendMessage: String?) {

//        FriendModel *friendModel = [[DBManager shared] matchAccurateFriendWithTableName: @"friends" withPhone: callee];\
        let friendModel = DBManager.shared.matchAccurateFriend(withTableName: friendsDB, withPhone: caller)
        if friendModel == nil {
            FriendViewModel().onlyfindFriendFromServer(finished: { [weak self] (success, error) in
                self?.ShouldGoNetCallViewController(callID, from: caller, type: type)
            })
        } else {
            ShouldGoNetCallViewController(callID, from: caller, type: type)
        }
    }
    
    fileprivate func ShouldGoNetCallViewController(_ callID: UInt64, from caller: String, type: NIMNetCallMediaType) {
        
        if LocalNotificationManager.shared.stayChatViewController {
            NIMAVChatSDK.shared().netCallManager.control(callID, type: NIMNetCallControlType.busyLine)
            return
        }
        
        let viewController: UIViewController?
        
        switch type {
        case .video:
            viewController = BVideoChatViewController(caller: caller, callId: callID)
            break
        case .audio:
            viewController = BAudioChatViewController(caller: caller, callId: callID)
            break
        }
        
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromTop
        
        if let rootViewController = (UIApplication.shared.keyWindow?.rootViewController as? BaseTabbarViewController)?.selectedViewController as? UINavigationController {
            
            rootViewController.view.layer.add(transition, forKey: nil)
            rootViewController.isNavigationBarHidden = true
            if ((rootViewController.presentedViewController) != nil) {
                rootViewController
                    .presentedViewController?.dismiss(animated: false, completion: nil)
            }
            viewController?.hidesBottomBarWhenPushed = true
            rootViewController.pushViewController(viewController!, animated: false)
        }
    }
    
    func onMultiLoginClientsChanged() {
        //在其他端上线
    }
 
    /// 登陆过程
    ///
    /// - Parameter step:
    func onLogin(_ step: NIMLoginStep) {
        if step == .loginOK {
            print("登陆成功")
        }
    }
    
    func onAutoLoginFailed(_ error: Error) {
        print("云信自动登录失败 \(error)")
    }
    
}
