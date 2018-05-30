//
//  ChatTableViewCell.swift
//  AirTalk
//
//  Created by GavinWinner on 2018/3/7.
//  Copyright © 2018年 边智峰. All rights reserved.
//

import UIKit
import NIMSDK
import NIMAVChat
import SDWebImage.SDWebImageManager
///  代理
protocol ChatTableViewCellDelegate: NSObjectProtocol {
    
    func chatTableViewShoulNetCall(netCallType: NIMNetCallType)
    func chatTableViewShoulReloadingCell(cell: ChatTableViewCell?)
    func chatTableViewShoulGoProfile()
}

class ChatTableViewCell: UITableViewCell {

    /// 聊天界面基本Margin参数
    var labelMargin: CGFloat = 20
    var labelTopMargin: CGFloat = 8
    var labelBottomMargin: CGFloat = 8
    var cellItemMargin: CGFloat = 10
    var cellIconImgWH: CGFloat = 40
    var cellIconImgRadius: CGFloat = 20
    var maxContainerWidth: CGFloat = 220
    var maxLabelWidth: CGFloat = 180
    var maxChatImgViewWidth: CGFloat = 200
    var maxChatImgViewHeight: CGFloat = 300
    var isMineSend: Bool?
    var netCallType: NIMNetCallType?
    weak var chatTableView_delegate: ChatTableViewCellDelegate?
    
    lazy var container: UIView = {
        let lazyView = UIView()
        lazyView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(playVoice)))
        return lazyView
    }()
    lazy var containerBackImgView: UIImageView = {
        let lazyView = UIImageView()
        return lazyView
    }()
    lazy var netCallImgView: UIImageView = {
        let lazyView = UIImageView()
        lazyView.contentMode = .center
        lazyView.animationDuration = 0.75
        lazyView.animationRepeatCount = Int.max
        return lazyView
    }()
    lazy var label: UILabel = {
        let lazyView = UILabel(Point: CGPoint.zero, text: "", TextColor: .white, textFont: PingFangMediumFont(withSize: 15), isEnabled: false, alignment: NSTextAlignment.left, numberLine: 0)
        return lazyView
    }()

    lazy var iconImgView: UIImageView = {
        let lazyView = UIImageView(frame: CGRect.zero, isNetImage: false, localImage: "", netImageUrl: "", radius: cellIconImgRadius, borderWidth: 0, boderColor: nil)
        lazyView.isUserInteractionEnabled = true
        lazyView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(shouldGoProfile)))
        return lazyView
    }()
    lazy var messageImgView: UIImageView = {
        let lazyView = UIImageView(frame: CGRect.zero, isNetImage: false, localImage: "", netImageUrl: "", radius: 5, borderWidth: 0, boderColor: nil)
        lazyView.backgroundColor = RGB(r: 216, g: 216, b: 216)
        return lazyView
    }()
    lazy var maskImgView: UIImageView = {
        let lazyView = UIImageView()
        return lazyView
    }()
    
    lazy var noPlayView: UIView = {
        let lazyView = UIView(frame: CGRect.zero, backGroundColor: RGB(r: 245, g: 25, b: 56), radius: 4)
        return lazyView
    }()
    
    lazy var sendFailedButton: UIButton = {
        let lazyView = UIButton(frame: CGRect.zero, text: "", normalImage: "chat_sendFailed", selectImage: "", imageEdge: nil)
        return lazyView
    }()
    
    lazy var sendingView: UIActivityIndicatorView = {
        let lazyView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        lazyView.hidesWhenStopped = true
        return lazyView
    }()
    
    ///数据
    @objc var message: IMChatMsg? {
        didSet {
            updateUIAndShowData()
        }
    }
    
    var currentChatModel: ChatModel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }

}


// MARK: - 事件
extension ChatTableViewCell {

    /// 播放语音
    @objc fileprivate func playVoice() {
        if message?.msg?.messageType == .audio {
            if isMineSend == false {
                message?.msg?.isPlayed = true
                noPlayView.isHidden = true
            }
            ChatSoundRecorder.sharedInstance.playOrStopMediaAudio(withMsg: message!, lastCell: self)
        } else if message?.msg?.messageType == .notification {
            if netCallType == .audio {
                chatTableView_delegate?.chatTableViewShoulNetCall(netCallType: .audio)
            } else if netCallType == .video {
                chatTableView_delegate?.chatTableViewShoulNetCall(netCallType: .video)
            }
        } else if message?.msg?.messageType == .image {
            UIApplication.shared.keyWindow?.endEditing(true)
            if let imgObj = message?.msg?.messageObject as? NIMImageObject {
                let v = InspectOriginalImageView(frame: CGRect(x: 0, y: 0, width: KWidth, height: KHeight), thumbImageUrl: imgObj.thumbUrl, originalImageUrl: imgObj.url, filePath: imgObj.path, fileLength: imgObj.fileLength, fileSize: imgObj.size, isMineSend: isMineSend, msg: message)
                UIApplication.shared.keyWindow?.addSubview(v)
                v.loadingOriginalBlock = { [weak self] in
                    
                    self?.chatTableView_delegate?.chatTableViewShoulReloadingCell(cell: self)
                }
            }
            
        }
    }
    
    /// 开启或者关闭语音动画
    func startOrStopVoiceAnimation(start: Bool) {
        if start == true {
            let imageNames = isMineSend == true ? [ImageOfAssets(withName: "chat_self_voice1"),
                                                   ImageOfAssets(withName: "chat_self_voice2"),
                                                   ImageOfAssets(withName: "chat_self_voice")]:
                                                   [ImageOfAssets(withName: "chat_other_voice1"),
                                                    ImageOfAssets(withName: "chat_other_voice2"),
                                                    ImageOfAssets(withName: "chat_other_voice")]
            netCallImgView.animationImages = imageNames
            netCallImgView.startAnimating()
        } else {
            netCallImgView.stopAnimating()
        }
    }
    
    /// 去好友主页
    @objc func shouldGoProfile() {
        chatTableView_delegate?.chatTableViewShoulGoProfile()
    }
}

// MARK: - UI
extension ChatTableViewCell {
    
    fileprivate func setupView() {
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(iconImgView)
        contentView.addSubview(container)
        contentView.addSubview(noPlayView)
        contentView.addSubview(sendFailedButton)
        contentView.addSubview(sendingView)
        
        container.addSubview(label)
        container.addSubview(messageImgView)
        container.addSubview(netCallImgView)
        
        container.insertSubview(containerBackImgView, at: 0)
        
        setupAutoHeight(withBottomView: container, bottomMargin: 0)
        
        containerBackImgView.sd_layout().spaceToSuperView(UIEdgeInsets.zero)
        
        noPlayView.mas_makeConstraints { (make) in
            make?.left.mas_equalTo()(container.mas_right)?.setOffset(4)
            make?.top.mas_equalTo()(container.mas_top)?.setOffset(4)
            make?.width.mas_equalTo()(8)
            make?.height.mas_equalTo()(8)
        }
        
        sendFailedButton.mas_makeConstraints { (make) in
            make?.right.mas_equalTo()(container.mas_left)?.setOffset(-4)
            make?.top.mas_equalTo()(container.mas_top)?.setOffset(4)
            make?.width.mas_equalTo()(30)
            make?.height.mas_equalTo()(30)
        }
        
        sendingView.mas_makeConstraints { (make) in
            make?.right.mas_equalTo()(container.mas_left)?.setOffset(-4)
            make?.top.mas_equalTo()(container.mas_top)?.setOffset(4)
            make?.width.mas_equalTo()(30)
            make?.height.mas_equalTo()(30)
        }
    }
    
    fileprivate func updateUIAndShowData() {

        ///清理约束 防止重用UI重叠
        label.frame = .zero
        container.frame = .zero
        iconImgView.frame = .zero
        messageImgView.frame = .zero
        maskImgView.frame = .zero
        label.sd_clearAutoLayoutSettings()
        container.sd_clearAutoLayoutSettings()
        iconImgView.sd_clearAutoLayoutSettings()
        messageImgView.sd_clearAutoLayoutSettings()
        netCallImgView.isHidden = true
        noPlayView.isHidden = true
        sendFailedButton.isHidden = true
        sendingView.stopAnimating()
        label.text = message?.msg?.text ?? ""
        label.font = PingFangMediumFont(withSize: 15)
        containerBackImgView.backgroundColor = .clear
        containerBackImgView.layer.cornerRadius = 0
        setupOrigin()
        switch (message?.msg?.messageType)! {
            case NIMMessageType.image:
                container.clearAutoWidthSettings()
                
                let standardWidthHeightRatio = maxChatImgViewWidth / maxChatImgViewHeight
                var widthHeightRatio: CGFloat = 0
                if let imgObj = message?.msg?.messageObject as? NIMImageObject {
                    let imgUrl = URL(string: imgObj.thumbUrl ?? "") //加载缩略图
                    let originalImgUrl = URL(string: imgObj.url ?? "")//加载原图
                    let imgSize = imgObj.size

                    var h = imgSize.height
                    var w = imgSize.width
                    
                    var downOption = SDWebImageOptions.progressiveDownload
                    if w > 1024 || h > 1024 {
                        downOption = .scaleDownLargeImages
                    }
                    
                    if w > maxChatImgViewWidth || h > maxChatImgViewHeight {
                        widthHeightRatio = w / height
                        
                        if widthHeightRatio > standardWidthHeightRatio {
                            w = maxChatImgViewWidth
                            h = w * (imgSize.height / imgSize.width)
                        } else {
                            h = maxChatImgViewHeight
                            w = h * widthHeightRatio
                        }
                    }
                    
                    messageImgView.size = CGSize(width: w, height: h)
                    _ = container.sd_layout().widthIs(w)?.heightIs(h)
                    container.setupAutoHeight(withBottomView: messageImgView, bottomMargin: 0)

                    if isMineSend == true {
                        if imgObj.path != nil {
                            messageImgView.sd_setImage(with: URL(fileURLWithPath: imgObj.path ?? ""))
                        } else {
                            messageImgView.sd_setImage(with: originalImgUrl, placeholderImage: nil, options: downOption, completed: nil)
                        }
                    } else {
                        SDWebImageManager.shared().diskImageExists(for: originalImgUrl, completion: { [weak self] (exist) in
                            if exist {
                                self?.messageImgView.sd_setImage(with: originalImgUrl, placeholderImage: nil, options: downOption, completed: nil)
                            } else {
                                self?.messageImgView.sd_setImage(with: imgUrl, placeholderImage: nil, options: downOption, completed: nil)
                            }
                        })
                    }
                       
                    containerBackImgView.didFinishAutoLayoutBlock = { [weak self] (finalFrame) in
                        self?.maskImgView.size = finalFrame.size
                    }
                }
                
                break
            case NIMMessageType.text:
                container.layer.mask?.removeFromSuperlayer()
                containerBackImgView.didFinishAutoLayoutBlock = nil
                _ = label.sd_resetLayout()
                    .leftSpaceToView(container, labelMargin)?
                    .topSpaceToView(container, labelTopMargin)?
                    .autoHeightRatio(0)
                label.setSingleLineAutoResizeWithMaxWidth(maxContainerWidth)
                //宽高自适应
                container.setupAutoWidth(withRightView: label, rightMargin: labelMargin)
                container.setupAutoHeight(withBottomView: label, bottomMargin: labelBottomMargin)
                break
            case NIMMessageType.audio:
                setupVoiceUI()
                break
            
            case NIMMessageType.notification:
                netCallImgView.isHidden = false
                ChatManager.netcallNotificationFormatedMessage(message: message?.msg, finished: { [weak self] (netCallType, text) in
                    self?.label.text = text
                    self?.setupNetCallImage(withType: netCallType)
                })
                
                container.layer.mask?.removeFromSuperlayer()
                containerBackImgView.didFinishAutoLayoutBlock = nil

                _ = netCallImgView.sd_resetLayout()
                    .leftSpaceToView(container, 15)?
                    .centerYEqualToView(container)?
                    .widthIs(25)?
                    .heightIs(25)
                
                _ = label.sd_resetLayout()
                    .leftSpaceToView(netCallImgView, 10)?
                    .topSpaceToView(container, labelTopMargin)?
                    .autoHeightRatio(0)
                label.setSingleLineAutoResizeWithMaxWidth(maxContainerWidth)
                //宽高自适应
                container.setupAutoWidth(withRightView: label, rightMargin: labelMargin)
                container.setupAutoHeight(withBottomView: label, bottomMargin: labelBottomMargin)
                break
            
            case NIMMessageType.custom:
                setupCustomUI()
                break
            default:
                break
        }
        
    }
    
    fileprivate func setupVoiceUI() {
        container.frame = .zero
        container.sd_clearAutoLayoutSettings()
        container.clearAutoWidthSettings()
        label.frame = .zero
        label.sd_clearAutoLayoutSettings()

        netCallImgView.isHidden = false
        var contentWidth: CGFloat = 40
        if let imgObj = message?.msg?.messageObject as? NIMAudioObject {
            label.text = "\(imgObj.duration)\""
            contentWidth = ChatManager.voiceViewContentSize(withCellWidth: KWidth, message: imgObj)
        }
        if isMineSend == true {
            netCallImgView.image = ImageOfAssets(withName: "chat_self_voice")
            _ = netCallImgView.sd_resetLayout()
                .rightSpaceToView(container, 15)?
                .centerYEqualToView(container)?
                .widthIs(25)?
                .heightIs(25)
            
            _ = label.sd_resetLayout()
                .leftSpaceToView(container, 15)?
                .topSpaceToView(container, labelTopMargin)?
                .autoHeightRatio(0)

            _ = container.sd_resetLayout()
                .topSpaceToView(iconImgView, -30)?
                .rightSpaceToView(iconImgView, cellItemMargin)?
                .widthIs(contentWidth)
        } else {
            noPlayView.isHidden = message?.msg?.isPlayed ?? false
            netCallImgView.image = ImageOfAssets(withName: "chat_other_voice")
            _ = netCallImgView.sd_resetLayout()
                .leftSpaceToView(container, 15)?
                .centerYEqualToView(container)?
                .widthIs(25)?
                .heightIs(25)
            
            _ = label.sd_resetLayout()
                .rightSpaceToView(container, 15)?
                .topSpaceToView(container, labelTopMargin)?
                .autoHeightRatio(0)
            
            _ = container.sd_resetLayout()
                .topSpaceToView(iconImgView, -30)?
                .leftSpaceToView(iconImgView, cellItemMargin)?
                .widthIs(contentWidth)
        }
        label.setSingleLineAutoResizeWithMaxWidth(maxContainerWidth)
        container.layer.mask?.removeFromSuperlayer()
        containerBackImgView.didFinishAutoLayoutBlock = nil
        //宽高自适应
        container.setupAutoHeight(withBottomView: label, bottomMargin: labelBottomMargin)
        
    }
    
    fileprivate func setupCustomUI() {
        label.font = PingFangFont(withSize: 12)
        label.textColor = RGB(r: 102, g: 102, b: 102, a: 0.5)
        container.frame = .zero
        container.sd_clearAutoLayoutSettings()
        container.clearAutoWidthSettings()
        label.frame = .zero
        label.sd_clearAutoLayoutSettings()

        label.text = "\(HandDate.achieveDayFormateByTimeString(timeInterval: (message?.msg?.timestamp)!, showWeek: false))"
        
        _ = label.sd_resetLayout()
            .leftSpaceToView(container, 10)?
            .topSpaceToView(container, 5)?
            .autoHeightRatio(0)
        label.setSingleLineAutoResizeWithMaxWidth(maxContainerWidth)
        label.updateLayout()
        
        _ = container.sd_resetLayout()
            .centerXEqualToView(contentView)?
            .topSpaceToView(contentView, 15)
        
        container.layer.mask?.removeFromSuperlayer()
        containerBackImgView.didFinishAutoLayoutBlock = nil
        //宽高自适应
        container.setupAutoWidth(withRightView: label, rightMargin: 10)
        container.setupAutoHeight(withBottomView: label, bottomMargin: 5)
        container.updateLayout()
        
        containerBackImgView.image = nil
        containerBackImgView.backgroundColor = RGB(r: 219, g: 219, b: 219)
        containerBackImgView.layer.cornerRadius = container.height * 0.5
    }
    
    fileprivate func setupNetCallImage(withType: NIMNetCallType) {
        netCallType = withType
        switch withType {
            case .audio:
                if isMineSend == true {
                    netCallImgView.image = ImageOfAssets(withName: "chat_mine_audio")
                } else {
                    netCallImgView.image = ImageOfAssets(withName: "chat_other_audio")
                }
                break
            case .video:
                
                if isMineSend == true {
                    netCallImgView.image = ImageOfAssets(withName: "chat_mine_video")
                } else {
                    netCallImgView.image = ImageOfAssets(withName: "chat_other_video")
                }
                break
        }
    }
    
    fileprivate func setupOrigin() {
        
        if message?.msg?.messageType == .custom {
            return
        }
        
        sendFailedButton.isHidden = message?.status == .SendFail ? false:true
        message?.status == .Sending ? sendingView.startAnimating():sendingView.stopAnimating()
        
        if message?.msg?.from == message?.msg?.session?.sessionId {
            isMineSend = false
            label.textColor = RGB(r: 102, g: 102, b: 102)
            netCallImgView.image = ImageOfAssets(withName: "chat_other_video")
            iconImgView.sd_setImage(with: URL(string: currentChatModel?.avatar ?? ""), placeholderImage: UIImage(named: "normalAvatar"))
            
            _ = iconImgView.sd_resetLayout()
                .leftSpaceToView(contentView, cellItemMargin)?
                .topSpaceToView(contentView, cellItemMargin)?
                .widthIs(cellIconImgWH)?
                .heightIs(cellIconImgWH)
            
            _ = container.sd_resetLayout()
                .topSpaceToView(iconImgView, -30)?
                .leftSpaceToView(iconImgView, cellItemMargin)
            
            containerBackImgView.image = ImageOfAssets(withName: "chat_other_bubble")
            
        } else {
            isMineSend = true
            label.textColor = UIColor.white
            netCallImgView.image = ImageOfAssets(withName: "chat_mine_video")
            
            if let userModel = ATUserModel.userModelGetLoginSuccessResult(),
               let user = userModel.user {
                iconImgView.sd_setImage(with: URL(string: user.avatarUrl), placeholderImage: UIImage(named: "normalAvatar"))
            }
            
            _ = iconImgView.sd_resetLayout()
                .rightSpaceToView(contentView, cellItemMargin)?
                .topSpaceToView(contentView, cellItemMargin)?
                .widthIs(cellIconImgWH)?
                .heightIs(cellIconImgWH)
            
            _ = container.sd_resetLayout()
                .topSpaceToView(iconImgView, -30)?
                .rightSpaceToView(iconImgView, cellItemMargin)

            containerBackImgView.image = ImageOfAssets(withName: "chat_mine_bubble")
        }
        
        if message?.msg?.messageType == NIMMessageType.image {
            containerBackImgView.image = ImageOfAssets(withName: "")
        }
        
        maskImgView.image = containerBackImgView.image
    }
    
}



