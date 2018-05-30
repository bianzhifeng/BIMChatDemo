//
//  ChatViewController.swift
//  AirTalk
//
//  Created by GavinWinner on 2018/3/5.
//  Copyright © 2018年 边智峰. All rights reserved.
//

import UIKit
import NIMSDK
import NIMAVChat
import MJRefresh
import AVFoundation

enum EditState: Int {
    case soundRecord //语音
    case textInput //文字
    case normal //默认
}

class ChatViewController: BaseViewController {

    var currentChatModel: ChatModel?
    var session: NIMSession?
    lazy var tableView: UITableView = {
        let lazyView = UITableView()
        lazyView.delegate = self
        lazyView.dataSource = self
        lazyView.backgroundColor = .clear
        lazyView.separatorStyle = .none
        lazyView.register(ChatTableViewCell.self, forCellReuseIdentifier: "ChatTableViewCell")
        
        let tableViewWrapper = MJRefreshNormalHeader(refreshingTarget: self, refreshingAction: #selector(LoadLastMessages))

        lazyView.mj_header = tableViewWrapper
        return lazyView
    }()
    lazy var MessageList = [IMChatMsg]()
    
    lazy var containInputView: UIView = {
        let lazyView = UIView(frame: CGRect.zero, backGroundColor: .white)
        return lazyView
    }()
    
    lazy var inputTextView: InputTextView = {
        let lazyView = InputTextView(frame: CGRect.zero)
        lazyView.delegate = self
        lazyView.font = PingFangMediumFont(withSize: 15)
        lazyView.textColor = RGB(r: 102, g: 102, b: 102)
        lazyView.returnKeyType = .send
        lazyView.textContainerInset = UIEdgeInsetsMake(10, 14, 9, 14)
        lazyView.showsVerticalScrollIndicator = false
        lazyView.maxNumberOfLines = 5
        return lazyView
    }()
    lazy var moreButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_more"), for: .normal)
        lazyButton.addTarget(self, action: #selector(moreButtonClick(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    lazy var moreView: UIView = {
        let lazyView = UIView(frame: CGRect.zero, backGroundColor: .white)
        lazyView.alpha = 0
        return lazyView
    }()
    lazy var cameraButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_takephoto"), for: .normal)
        lazyButton.addTarget(self, action: #selector(cameraButtonClick(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    lazy var photoButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_photo"), for: .normal)
        lazyButton.addTarget(self, action: #selector(photoButtonClick(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    lazy var VideoButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_video"), for: .normal)
        lazyButton.addTarget(self, action: #selector(videoButtonClick(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    lazy var AudioButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_audio"), for: .normal)
        lazyButton.addTarget(self, action: #selector(audioButtonClick(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    lazy var voiceButton: UIButton = {
        let lazyButton = UIButton()
        lazyButton.setImage(ImageOfAssets(withName: "chat_voice"), for: .normal)
        lazyButton.setImage(ImageOfAssets(withName: "chat_voice_select"), for: .selected)
        lazyButton.addTarget(self, action: #selector(ShowRecordView(sender:)), for: .touchUpInside)
        return lazyButton
    }()
    
    lazy var PictureImgViewController: UIImagePickerController = {
        let imgController = UIImagePickerController()
        imgController.delegate = self
        imgController.allowsEditing = false
        imgController.modalTransitionStyle = .flipHorizontal
        return imgController
    }()
    
    var wasKeyboardManagerEnabled: Bool?
    var isShowMoreView: Bool?
    
    var recordSoundView: RecordSoundView?
    var state: EditState = EditState.normal
    
    /// 用来重新进入输入状态时恢复高度
    var inputTextViewOldFrame: CGFloat = 40
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        updateNavItem()
        
        creatUI()
        
        addNotification()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        recordSoundView?.timeTimer?.invalidate()
        recordSoundView?.timeTimer = nil
        ChatSoundRecorder.destory()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    @objc convenience init(withChatModel: ChatModel) {
        self.init()
        currentChatModel = withChatModel
        
        session = NIMSession(currentChatModel?.sessionId ?? "", type: NIMSessionType.P2P)
        ChatManager.sharedInstance.currentSession = session
//        title = currentChatModel?.name ?? ""
        
        updateNavItemTitleView()
        
        if session != nil {
            NIMSDK.shared().conversationManager.markAllMessagesRead(in: session!)

            loadMessage()
            recvMessage()
            sendMsgCompletion()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?){
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    deinit {
        ChatManager.sharedInstance.currentSession = nil
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - 消息事件
extension ChatViewController {
    
    fileprivate func loadMessage() {
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + 0.25, execute: {
            self.MessageList = ChatManager.sharedInstance.getAnyConversationMessage(withSession: self.session!, message: nil, limit: 6)
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.scrollTableViewToBottom()
            }
        })
    }
    
    @objc fileprivate func LoadLastMessages() {
        DispatchQueue.global().async {
            var firstMsg = self.MessageList.first
            if firstMsg?.msg?.messageType == .custom && self.MessageList.count > 1 {
                firstMsg = self.MessageList[1]
            }

            let lastMsgs = ChatManager.sharedInstance.getAnyConversationMessage(withSession: self.session!, message: firstMsg, limit: 6)
            self.tableView.mj_header.endRefreshing()
            if lastMsgs.count > 0 {
                self.MessageList = lastMsgs + self.MessageList
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    fileprivate func recvMessage() {
        
        ChatManager.sharedInstance.recvMsgBlock = { [weak self] (msgs) in
            if (self?.MessageList.count ?? 0) > 0 {
                self?.tableView.beginUpdates()
                
                self?.MessageList += msgs
                
                var idxArray = [IndexPath]()
                for newMsg in msgs {
                    if let idx = self?.MessageList.index(of: newMsg) {
                        let indexPath = IndexPath(row: idx, section: 0)
                        idxArray.append(indexPath)
                    }
                }
                self?.tableView.insertRows(at: idxArray, with: .fade)
                self?.tableView.endUpdates()
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.25, execute: {
                    let indexPath = IndexPath(row: ((self?.MessageList.count) ?? 1) - 1, section: 0)
                    self?.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.bottom, animated: true)
                })
            } else {
                self?.MessageList = msgs
                self?.tableView.reloadData()
            }
        }
    }
    
    /// 发送消息成功/失败
    fileprivate func sendMsgCompletion() {
        ChatManager.sharedInstance.sendMsgBlock = { [weak self] (status, messageId) in
            if (self?.MessageList.count ?? 0) > 0 {
                for msg in (self?.MessageList.reversed()) ?? [] {
                    if msg.msg?.messageId == messageId {
                        msg.status = status
                        if let idx = self?.MessageList.index(of: msg) {
                            self?.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
                        }
                        return
                    }
                }
            }
        }
    }
}

// MARK: - UI
extension ChatViewController {
    
    fileprivate func creatUI() {
        view.addSubview(tableView)
        tableView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleSingleTap)))
        
        view.addSubview(moreView)
        view.addSubview(containInputView)
        containInputView.addSubview(inputTextView)
        containInputView.addSubview(moreButton)
        containInputView.addSubview(voiceButton)
        
        
        moreView.addSubview(cameraButton)
        moreView.addSubview(photoButton)
        moreView.addSubview(VideoButton)
        moreView.addSubview(AudioButton)

        
        containInputView.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(view.mas_left)
            make?.right.mas_equalTo()(view.mas_right)
            if returnNavBarH() == 88 {
                make?.height.mas_equalTo()(94)
            } else {
                make?.height.mas_equalTo()(60)
            }
            make?.bottom.mas_equalTo()(view.mas_bottom)
        }
        
        tableView.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(view.mas_left)
            make?.right.mas_equalTo()(view.mas_right)
            make?.top.mas_equalTo()(view)
            make?.bottom.mas_equalTo()(containInputView.mas_top)?.setInset(15)
        }
        
        inputTextView.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(view.mas_left)?.setOffset(47)
            make?.height.mas_equalTo()(40)
            make?.right.mas_equalTo()(view.mas_right)?.setOffset(-48)
            make?.top.mas_equalTo()(containInputView)?.setOffset(10)
        }
        
        voiceButton.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(containInputView.mas_left)?.setOffset(5)
            make?.bottom.mas_equalTo()(inputTextView.mas_bottom)
            make?.width.mas_equalTo()(40)
            make?.height.mas_equalTo()(40)
        }
        
        moreButton.mas_makeConstraints { (make) in
            make?.right.mas_equalTo()(containInputView.mas_right)?.setOffset(-6)
            make?.bottom.mas_equalTo()(inputTextView.mas_bottom)
            make?.width.mas_equalTo()(40)
            make?.height.mas_equalTo()(40)
        }
        
        moreView.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(view.mas_left)
            make?.right.mas_equalTo()(view.mas_right)
            make?.bottom.mas_equalTo()(containInputView.mas_top)?.setOffset(45)
            make?.height.mas_equalTo()(45)
        }
        
        photoButton.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(moreView.mas_left)?.setOffset(3.5)
            make?.centerY.mas_equalTo()(moreView)
            make?.width.mas_equalTo()(45)
            make?.height.mas_equalTo()(45)
        }
        
        cameraButton.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(photoButton.mas_right)?.setOffset(8)
            make?.centerY.mas_equalTo()(moreView)
            make?.width.mas_equalTo()(45)
            make?.height.mas_equalTo()(45)
        }
        
        AudioButton.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(cameraButton.mas_right)?.setOffset(9)
            make?.centerY.mas_equalTo()(moreView)
            make?.width.mas_equalTo()(45)
            make?.height.mas_equalTo()(45)
        }
        
        VideoButton.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(AudioButton.mas_right)?.setOffset(10)
            make?.centerY.mas_equalTo()(moreView)
            make?.width.mas_equalTo()(45)
            make?.height.mas_equalTo()(45)
        }

        recordSoundView = RecordSoundView()
        view.addSubview(recordSoundView!)
        _ = recordSoundView?.mas_makeConstraints({ (make) in
            make?.left.mas_equalTo()(view)
            make?.right.mas_equalTo()(view)
            make?.top.mas_equalTo()(view.mas_bottom)
            if returnNavBarH() == 88 {
                make?.height.mas_equalTo()(234)
            } else {
                make?.height.mas_equalTo()(200)
            }
        })
        
        
        inputTextView.inputChangeHeightBlock = { [weak self] (text, contentHeight) in
            self?.updateInputUI(withHeight: contentHeight)
            self?.inputTextViewOldFrame = contentHeight
        }
        
    }
    
    fileprivate func updateInputUI(withHeight: CGFloat) {
        containInputView.mas_updateConstraints({ (make) in
            make?.height.mas_equalTo()(withHeight + 20)
        })
        inputTextView.mas_updateConstraints({ (make) in
            make?.height.mas_equalTo()(withHeight)
        })
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    fileprivate func updateInputUIWhenKeyBoardShow(keyboardHeight: CGFloat) {
        
        containInputView.mas_updateConstraints({ (make) in
            make?.bottom.mas_equalTo()(self.view.mas_bottom)?.setOffset(-keyboardHeight)
            make?.height.mas_equalTo()(self.inputTextViewOldFrame + 20)
        })
        if inputTextViewOldFrame > 40 {
            inputTextView.mas_updateConstraints({ (make) in
                make?.height.mas_equalTo()(self.inputTextViewOldFrame)
            })
        }
        UIView.animate(withDuration: 0.2) {
            self.view.layoutIfNeeded()
        }
    }
    
    
    fileprivate func updateNavItem() {
        view.addGestureRecognizer(UIPanGestureRecognizer(target: navigationController?.interactivePopGestureRecognizer?.delegate, action: nil))
        
        view.backgroundColor = RGB(r: 235, g: 235, b: 235)
        
        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationController?.navigationBar.setBackgroundImage(ImageOfAssets(withName: "nav_back"), for: .default)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(target: self, action: #selector(backButtonClick), image: ImageOfAssets(withName: "nav_backLast"), imageEdgeInsets: UIEdgeInsetsMake(0, 0, 0, 0), size: CGSize(width: 40, height: 40))
        
        navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.font:PingFangBoldFont(withSize: 20) ?? UIFont(),
            NSAttributedStringKey.foregroundColor: UIColor.white]
    }
    
    fileprivate func updateNavItemTitleView() {
        let reTitleView = UIView(frame: CGRect(x: 0, y: returnNavBarH() - 44, width: KWidth * 0.7, height: 44), backGroundColor: UIColor.clear)
        let titleLabel = UILabel(Point: CGPoint.zero, text: currentChatModel?.name, TextColor: .white, textFont: PingFangBoldFont(withSize: 20), isEnabled: false, alignment: .center, numberLine: 1)
        titleLabel.frame = reTitleView.bounds
        reTitleView.addSubview(titleLabel)
        navigationItem.titleView = reTitleView
    }
    
    fileprivate func addNotification() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyBoardWillShow(noti:)),
                                               name: NSNotification.Name.UIKeyboardWillChangeFrame,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyBoardWillHidden(noti:)),
                                               name: NSNotification.Name.UIKeyboardWillHide,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyBoardDidHidden(noti:)),
                                               name: NSNotification.Name.UIKeyboardDidHide,
                                               object: nil)
        
        ChatSoundRecorder.sharedInstance.recorder_delegate = self
    }
    

    
}

// MARK: - 事件
extension ChatViewController {
    
    @objc fileprivate func backButtonClick() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc fileprivate func handleSingleTap() {
        if inputTextView.isFirstResponder {
            inputTextView.resignFirstResponder()
            inputTextView.contentOffset = CGPoint.zero
            containInputView.mas_updateConstraints({ (make) in
                if returnNavBarH() == 88 {
                    make?.height.mas_equalTo()(94)
                } else {
                    make?.height.mas_equalTo()(60)
                }
            })
            
            inputTextView.mas_updateConstraints({ (make) in
                make?.height.mas_equalTo()(40)
            })
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        } else if voiceButton.isSelected {
            voiceButton.isSelected = false
            _ = recordSoundView?.mas_updateConstraints({ (make) in
                make?.top.mas_equalTo()(view.mas_bottom)
            })
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(self.view.mas_bottom)
                if returnNavBarH() == 88 {
                    make?.height.mas_equalTo()(94)
                } else {
                    make?.height.mas_equalTo()(60)
                }
            })
            UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
        }
    }
    
    @objc fileprivate func moreButtonClick(sender: UIButton) {
        var moreViewAlpha: CGFloat = 0
        var rotateAngle = CGFloat(Double.pi / 4)
        if sender.isSelected == true {
            rotateAngle = 0
            moreView.mas_updateConstraints { (make) in
                make?.bottom.mas_equalTo()(containInputView.mas_top)?.setOffset(45)
            }
        } else {
            inputTextView.resignFirstResponder()
            moreViewAlpha = 1
            rotateAngle = CGFloat(Double.pi / 4)
            moreView.mas_updateConstraints { (make) in
                make?.bottom.mas_equalTo()(containInputView.mas_top)?.setOffset(-1)
            }
        }
        sender.isSelected = !sender.isSelected
        UIView.animate(withDuration: 0.25) {
            self.moreView.alpha = moreViewAlpha
            self.moreButton.transform = CGAffineTransform.identity.rotated(by: rotateAngle)
            self.view.layoutIfNeeded()
        }
    }
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        voiceButton.isSelected = false
        _ = recordSoundView?.mas_updateConstraints({ (make) in
            make?.top.mas_equalTo()(view.mas_bottom)
        })
        return true
    }
    
    //MARK: -键盘事件
    @objc fileprivate func keyBoardWillShow(noti: Notification!) {
        if voiceButton.isSelected == true {
            return
        }
        
        let value = noti.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject
        let rect: CGRect = value.cgRectValue
        
        let keyBoardHeight = rect.height
        
        let animationTime = noti.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double
        
        if (animationTime ?? 0) > 0 {
            updateInputUIWhenKeyBoardShow(keyboardHeight: keyBoardHeight)
        } else {
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(view.mas_bottom)?.setOffset(-keyBoardHeight)
                make?.height.mas_equalTo()(60)
            })
        }
        
        scrollTableViewToBottom()
    }
    
    override func keyboardDidShow(_ noti: Notification!) {
        
    }
    
    @objc fileprivate func keyBoardWillHidden(noti: Notification!) {
        if voiceButton.isSelected == true {
            return
        }
        let animationTime = noti.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? Double
        
        if (animationTime ?? 0) > 0 {
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(self.view.mas_bottom)
                if returnNavBarH() == 88 {
                    make?.height.mas_equalTo()(94)
                } else {
                    make?.height.mas_equalTo()(60)
                }
            })
            UIView.animate(withDuration: animationTime!, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)

        } else {
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(view.mas_bottom)
                if returnNavBarH() == 88 {
                    make?.height.mas_equalTo()(94)
                } else {
                    make?.height.mas_equalTo()(60)
                }
            })
        }
    }
    
    @objc fileprivate func keyBoardDidHidden(noti: Notification!) {
        scrollTableViewToBottom()
    }
    
    fileprivate func scrollTableViewToBottom() {
        DispatchQueue.main.async {
            if self.MessageList.count > 0 {
                let indexPath = IndexPath(row: self.MessageList.count - 1, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }

    /// 显示录音控件
    ///
    /// - Parameter sender:
    @objc fileprivate func ShowRecordView(sender: UIButton) {
        sender.isSelected = !sender.isSelected
        
        if sender.isSelected == true {
            _ = recordSoundView?.mas_updateConstraints({ (make) in
                make?.top.mas_equalTo()(view.mas_bottom)?.setOffset(-(recordSoundView?.height)!)
            })
            
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(self.view.mas_bottom)?.setOffset(-((recordSoundView?.height)! + 1))
                make?.height.mas_equalTo()(60)
            })
            
            UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
            
            if inputTextView.isFirstResponder == true {
                state = EditState.textInput
                inputTextView.resignFirstResponder()
                
                inputTextView.contentOffset = CGPoint.zero
                inputTextView.mas_updateConstraints({ (make) in
                    make?.height.mas_equalTo()(40)
                })
            }
        } else {
            ResetToLastState()
        }

    }

    
    /// 重置位置及状态
    fileprivate func ResetToLastState() {
        switch state {
            case EditState.textInput:
                state = EditState.normal
                inputTextView.becomeFirstResponder()
                break
        case EditState.normal:
            _ = recordSoundView?.mas_updateConstraints({ (make) in
                make?.top.mas_equalTo()(view.mas_bottom)
            })
            self.containInputView.mas_updateConstraints({ (make) in
                make?.bottom.mas_equalTo()(self.view.mas_bottom)
                if returnNavBarH() == 88 {
                    make?.height.mas_equalTo()(94)
                } else {
                    make?.height.mas_equalTo()(60)
                }
            })
            UIView.animate(withDuration: 0.25, delay: 0, options: UIViewAnimationOptions.curveEaseIn, animations: {
                self.view.layoutIfNeeded()
            }, completion: nil)
            break
        default:
                break
        }
        
    }
    
    /// 视频通话
    ///
    /// - Parameter sender:
    @objc fileprivate func videoButtonClick(sender: UIButton) {
        moreButtonClick(sender: moreButton)
        let sessionController = BVideoChatViewController(callee: session?.sessionId)
        
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromTop
        self.navigationController?.view.layer.add(transition, forKey: nil)
        self.navigationController?.isNavigationBarHidden = true
        if ((self.navigationController?.presentedViewController) != nil) {
            self.navigationController?.presentedViewController?.dismiss(animated: false, completion: nil)
        }
        self.navigationController?.pushViewController(sessionController!, animated: false)
    }
    
    
    /// 语音通话
    ///
    /// - Parameter sender:
    @objc fileprivate func audioButtonClick(sender: UIButton) {
        moreButtonClick(sender: moreButton)
        let sessionController = BAudioChatViewController(callee: session?.sessionId)
        let transition = CATransition()
        transition.duration = 0.25
        transition.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionDefault)
        transition.type = kCATransitionPush
        transition.subtype = kCATransitionFromTop
        self.navigationController?.view.layer.add(transition, forKey: nil)
        self.navigationController?.isNavigationBarHidden = true
        if ((self.navigationController?.presentedViewController) != nil) {
            self.navigationController?.presentedViewController?.dismiss(animated: false, completion: nil)
        }
        self.navigationController?.pushViewController(sessionController!, animated: false)
    }
    
    
    /// 点击相机
    ///
    /// - Parameter sender:
    @objc fileprivate func cameraButtonClick(sender: UIButton) {
        moreButtonClick(sender: moreButton)
        ShowImgPickerWithType(imgPickerType: .camera)
    }
    
    /// 点击照片
    ///
    /// - Parameter sender:
    @objc fileprivate func photoButtonClick(sender: UIButton) {
        moreButtonClick(sender: moreButton)
        ShowImgPickerWithType(imgPickerType: .savedPhotosAlbum)
    }
    
    /// 打开相机
    ///
    /// - Parameter imgPickerType:
    fileprivate func ShowImgPickerWithType(imgPickerType: UIImagePickerControllerSourceType) {
        let openCamera = UIImagePickerController.isSourceTypeAvailable(imgPickerType)
        if openCamera == false {
            return
        }
        if imgPickerType == .camera {
            let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if authStatus == .restricted || authStatus == .denied {
                BCoreToolCenter.shared.ShowMessage(withDetail: "没有开启相机权限, 请去设置中开启")
                return
            }
        }
        PictureImgViewController.sourceType = imgPickerType
        present(PictureImgViewController, animated: true, completion: nil)
        
    }
}

// MARK: - 代理
extension ChatViewController: UITableViewDelegate, UITableViewDataSource, UITextViewDelegate,
                              UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                              ChatSoundRecorderDelegate, ChatTableViewCellDelegate
{
    func onChatWillSendMsg(msg: IMChatMsg?) {
        
    }
    
    func onChatCancelSendMsg(msg: IMChatMsg?) {
        
    }
    
    func onChatReplaceSendMsg(msg: IMChatMsg?) {
        ChatManager.sendMsg(withMsg: msg,
                            lastMsg: MessageList.last,
                            session: session,
                            chatModel: currentChatModel)
    }
    

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MessageList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chatCell = tableView.dequeueReusableCell(withIdentifier: "ChatTableViewCell") as? ChatTableViewCell
        chatCell?.currentChatModel = currentChatModel
        chatCell?.message = MessageList[indexPath.row]
        chatCell?.chatTableView_delegate = self
        return chatCell!
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.cellHeight(for: indexPath, model: MessageList[indexPath.row], keyPath: "message", cellClass: ChatTableViewCell.self, contentViewWidth: KWidth)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" || text.hasPrefix("\n") {
            if text != "" {
                ChatManager.sendMsg(withMsg: IMChatMsg.msgWithText(withText: textView.text),
                                    lastMsg: MessageList.last,
                                    session: session,
                                    chatModel: currentChatModel)
                textView.text = ""
                
                updateInputUI(withHeight: 40)
            }

            return false
        }
        return true
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        tableView.mas_updateConstraints { (make) in
            make?.bottom.mas_equalTo()(containInputView.mas_top)?.setInset(15)
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        tableView.mas_updateConstraints { (make) in
            make?.bottom.mas_equalTo()(containInputView.mas_top)
        }
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let image = info["UIImagePickerControllerOriginalImage"] as? UIImage else { return }
            
            ChatManager.sendMsg(withMsg: IMChatMsg.msgWithImage(withImage: image),
                                lastMsg: self?.MessageList.last,
                                session: self?.session,
                                chatModel: self?.currentChatModel)
            
        }
    }
    
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if #available(iOS 11.0, *) {
            if let PhotoClass = NSClassFromString("PUPhotoPickerHostViewController") {
                if viewController.isKind(of: PhotoClass) {
                    for (_, value) in viewController.view.subviews.enumerated() { // your code
                        if value.width < 42 {
                            viewController.view.sendSubview(toBack: value)
                            break
                        }
                    }
                }
            }
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if scrollView == tableView {
            handleSingleTap()
            tableView.mas_updateConstraints { (make) in
                make?.bottom.mas_equalTo()(containInputView.mas_top)
            }
            if moreButton.isSelected == true {
                moreButtonClick(sender: moreButton)
            }
        }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if decelerate == true && scrollView == tableView {
            tableView.mas_updateConstraints { (make) in
                make?.bottom.mas_equalTo()(containInputView.mas_top)
            }
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == tableView {
            tableView.mas_updateConstraints { (make) in
                make?.bottom.mas_equalTo()(containInputView.mas_top)
            }
        }
    }
    
    /// 视频/语音发起
    ///
    /// - Parameter netCallType: NIMNetCallType
    func chatTableViewShoulNetCall(netCallType: NIMNetCallType) {
        if netCallType == .audio {
            audioButtonClick(sender: AudioButton)
        } else if netCallType == .video {
            videoButtonClick(sender: VideoButton)
        }
    }
    
    /// 刷新
    ///
    /// - Parameter cell: ChatTableViewCell
    func chatTableViewShoulReloadingCell(cell: ChatTableViewCell?) {
        if let _ = cell,
           let indexPath = tableView.indexPath(for: cell!),
           indexPath.row < MessageList.count {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
        
    }
    
    /// 跳转到好友主页
    func chatTableViewShoulGoProfile() {
        if let friendModel = DBManager.shared.matchAccurateFriend(withTableName: friendsDB, withPhone: currentChatModel?.sessionId ?? "") {
            let profileViewController = FriendProfileViewController()
            profileViewController.hidesBottomBarWhenPushed = true
            profileViewController.friendModel = friendModel
            navigationController?.pushViewController(profileViewController, animated: true)
        }
    }
}
