//
//  SongViewController.swift
//  moments
//
//  Created by Pak on 09/08/16.
//  Copyright © 2016 paksnicefriends. All rights reserved.
//
// Play a selected song/video

import UIKit
import AVFoundation

class SongViewController: UIViewController, SPTAudioStreamingPlaybackDelegate, AVCaptureFileOutputRecordingDelegate {
    
    var momentTag: PFObject? {
        didSet {
            //Fetch video files from parse and save to a file
            if let videos = momentTag!["videos"] as? [PFObject] {
                
                downloadedVideos = 0
                videosToDownload = videos.count
                localVideoUrls = [NSURL]()
                
                for video in videos {
                    video.fetchIfNeededInBackgroundWithBlock {
                        (video: PFObject?, error: NSError?) -> Void in
                        if let video = video {
                            if let userVideoFile = video["videoFile"] as? PFFile {
                                userVideoFile.getDataInBackgroundWithBlock {
                                    (videoData: NSData?, error: NSError?) -> Void in
                                    if error == nil {
                                        if let videoData = videoData {
                                            let documentsUrl =  NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
                                            let destinationUrl = documentsUrl.URLByAppendingPathComponent(userVideoFile.name)
                                            
                                            if videoData.writeToURL(destinationUrl, atomically: true) {
                                                print("file saved [\(destinationUrl.path!)]")
                                                self.videoDownloaded(destinationUrl, error: nil) //success
                                            } else {
                                                print("error saving file")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            //print(videos?["videoFile"])
        }
    }
    
    var spotifyUrl: String? {
        didSet {
            
        }
    }
    
    var currentOffset: Float = 0 {
        didSet {
            if(currentOffset > videoDuration-0.1) {
                cameraLayer?.hidden = false
                videoPlayerLayer?.hidden = true
            } else {
                cameraLayer?.hidden = true
                videoPlayerLayer?.hidden = false
            }
        }
    }//In seconds
    
    @IBOutlet weak var slider: UISlider!
    
    @IBOutlet weak var mediaView: UIView!
    var videoPlayer: AVPlayer?
    var videoPlayerLayer: AVPlayerLayer?
    var videoDuration: Float = 0
    
    var videosToDownload = 2
    var downloadedVideos = 0
    var localVideoUrls = [NSURL]()
    
    var spotifyPlayer: SPTAudioStreamingController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spotifyPlayer = SPTAudioStreamingController.sharedInstance()
        spotifyPlayer?.playbackDelegate = self
        
        NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(updateSongProgress), userInfo: nil, repeats: true)
        
        initCamera(.Back)
        
        //TODO: Spinning wheel
    }
    
    func updateSongProgress() {
        if let spotifyPlayer = spotifyPlayer {
            if spotifyPlayer.isPlaying {
                let playbackPosition = spotifyPlayer.currentPlaybackPosition
                currentOffset = Float(playbackPosition)
                slider.value = currentOffset/Float(spotifyPlayer.currentTrackDuration)
                
                
            }
        }
    }
    
    func videoDownloaded(url: NSURL, error: NSError!) {
        //TODO: error handling (not downloaded)
        print("Video downloaded to \(url)")
        localVideoUrls.append(url)
        downloadedVideos += 1
        
        if downloadedVideos == videosToDownload {
            print(localVideoUrls)
            print("Download done")
            let stitchedVideo = StitchedVideo(videoUrls: localVideoUrls)
            
            videoPlayer = AVPlayer(playerItem: stitchedVideo.PlayerItem)
            videoPlayer?.actionAtItemEnd = .None
            videoDuration = Float(videoPlayer!.currentItem!.duration.seconds)
            
            videoPlayerLayer = AVPlayerLayer(player: videoPlayer)
            videoPlayerLayer!.frame = self.mediaView.bounds
            self.view.layer.addSublayer(videoPlayerLayer!)
        }
    }
    
    func reloadVideoPlayer() {
        let stitchedVideo = StitchedVideo(videoUrls: localVideoUrls)
        let shouldPlay = videoPlayer?.rate > 0
        videoPlayer = AVPlayer(playerItem: stitchedVideo.PlayerItem)
        videoPlayer?.actionAtItemEnd = .None
        videoDuration = Float(videoPlayer!.currentItem!.duration.seconds)
        videoPlayerLayer?.player = videoPlayer
        if shouldPlay {
            videoPlayer?.play()
        }
    }
    
    @IBAction func sliderChange(sender: UISlider) {
        print(sender.value)
        let musicDuration = Float(spotifyPlayer!.currentTrackDuration)
        let musicOffset = musicDuration * sender.value
        setMusicOffset(musicOffset)
    }
    
    func setMusicOffset(musicOffset: Float) {
        currentOffset = musicOffset
        
        var videoOffset = musicOffset
        if(musicOffset >= videoDuration) {
            videoOffset = videoDuration
        }
        videoPlayer?.seekToTime(CMTime(seconds: Double(videoOffset), preferredTimescale: 1), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
        spotifyPlayer?.seekToOffset(Double(musicOffset), callback: { (error: NSError!) in
            if error != nil {
                print("Seek error \(error)")
            }
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func mediaViewTapped(sender: AnyObject) {
        
        playPause()
    }
    
    func playPause() {
        if let videoPlayer = videoPlayer {
            
            print(videoPlayer.currentItem?.loadedTimeRanges)
            print(videoPlayer.rate)
            if videoPlayer.rate > 0 {
                print("pause")
                videoPlayer.pause()
                spotifyPlayer?.setIsPlaying(false, callback: { (error: NSError!) in
                    if error != nil {
                        print("Couldnt pause spotify")
                    }
                })
            } else {
                if videoPlayer.status == .ReadyToPlay {
                    print("play")
                    //videoPlayerLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
                    
                    if let spotifyUrl = spotifyUrl {
                        spotifyPlayer?.playURIs([NSURL(string: spotifyUrl)!], fromIndex: 0, callback: { (error: NSError!) in
                            if error != nil {
                                print("Couldnt play from spotify")
                            } else {
                                self.setMusicOffset(self.currentOffset)
                                videoPlayer.play()
                            }
                        })
                    }
                } else {
                    print("NOT READY!")
                }
            }
        }
    }
    
    // MARK: - Camera
    private var cameraLayer : AVCaptureVideoPreviewLayer?
    private var videoOutput : AVCaptureMovieFileOutput?
    private var session : AVCaptureSession?
    private var tm : NSTimer?
    func initCamera(position: AVCaptureDevicePosition)
    {
        var myDevice: AVCaptureDevice?
        let devices = AVCaptureDevice.devices()
        let audioDevices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
        
        // Back camera
        var videoInput: AVCaptureDeviceInput? = nil
        for device in devices
        {
            if(device.position == position)
            {
                myDevice = device as? AVCaptureDevice
                do {
                    videoInput = try AVCaptureDeviceInput(device: myDevice)
                }
                catch let error as NSError
                {
                    print(error)
                    return
                }
            }
        }
        
        // Audio
        var audioInput: AVCaptureDeviceInput? = nil
        if audioDevices.count > 0 {
            do {
                audioInput = try AVCaptureDeviceInput(device: audioDevices[0] as! AVCaptureDevice)
            }
            catch let error as NSError
            {
                print(error)
                return
            }
        }
        
        // Create session
        videoOutput = AVCaptureMovieFileOutput()
        //imgOutput = AVCaptureStillImageOutput()
        session = AVCaptureSession()
        session?.beginConfiguration()
        session?.sessionPreset = AVCaptureSessionPresetiFrame960x540
        
        if videoInput != nil {
            session?.addInput(videoInput)
        }
        if audioInput != nil {
            session?.addInput(audioInput)
        }
        //session?.addOutput(imgOutput)
        session?.addOutput(videoOutput)
        
        var connection = videoOutput?.connectionWithMediaType(AVMediaTypeVideo)
        connection?.videoOrientation = .Portrait
        
        session?.commitConfiguration()
        
        // Video Screen
        cameraLayer = AVCaptureVideoPreviewLayer(session: session)
        cameraLayer?.frame = mediaView.frame
        cameraLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        self.mediaView.layer.addSublayer(cameraLayer!)
        
        // Start session
        session?.startRunning()
    }
    
    @IBAction func takeVideo(sender: UILongPressGestureRecognizer) {
        switch sender.state
        {
        case UIGestureRecognizerState.Began:
            print("long tap begin")
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            guard let docDirectory = paths[0] as String? else
            {
                return
            }
            let path = "\(docDirectory)/temp.mp4"
            let url = NSURL(fileURLWithPath: path)
            videoOutput?.startRecordingToOutputFileURL(url, recordingDelegate: self)
            setMusicOffset(videoDuration)
            cameraLayer?.borderColor = UIColor.yellowColor().CGColor
            cameraLayer?.borderWidth = 10
            
            // Timer
            //tm = NSTimer.scheduledTimerWithTimeInterval(0.01, target: self, selector: Selector("recordVideo:"), userInfo: nil, repeats: true)
            
        case UIGestureRecognizerState.Ended:
            print("long tap end")
            //tm?.invalidate()
            videoOutput?.stopRecording()
            cameraLayer?.borderWidth = 0
            
            
        default:
            break
        }
    }
    
    // MARK: AVCaptureFileOutputRecordingDelegate
    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!)
    {
        print("didStartRecordingToOutputFileAtURL")
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!)
    {
        print("didFinishRecordingToOutputFileAtURL")
        
        //TODO: Spinning wheel
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        guard let docDirectory = paths[0] as String? else
        {
            return
        }
        let path = "\(docDirectory)/square.mp4"
        let url = NSURL(fileURLWithPath: path)
        //VideoCropper.cropSquareVideo(outputFileURL, outputUrl: url) { (result) in
        let videoFile = PFFile(data: NSData(contentsOfURL: outputFileURL)!)
        let video = PFObject(className: "MomentVideo")
        video["videoFile"] = videoFile
        //TODO: Spotify name
        video["contributor"] = "hacker"
        
        
        videoFile!.saveInBackgroundWithBlock({
            (succeeded: Bool, error: NSError?) -> Void in
            if succeeded {
                print("Uploading done!")
                
            }
            }, progressBlock: {
                (percentDone: Int32) -> Void in
                
                print("Uploading video: \(percentDone)%")
        })
        
        video.saveInBackgroundWithBlock( { (succeeded: Bool, error: NSError?) in
            print("saved video info \(video.objectId)")
        })
        
        
        
        //self.momentTag?.addObjectsFromArray([video], forKey: "videos")
        //self.momentTag?["videos"] = []
        /*self.momentTag?.saveInBackgroundWithBlock( { (succeeded: Bool, error: NSError?) in
            print("saved moment tag \(error)")
        })*/
        
        self.localVideoUrls.append(outputFileURL)
        let durationBeforeRecording = self.videoDuration
        self.reloadVideoPlayer()
        self.setMusicOffset(durationBeforeRecording)
        
    }
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}