/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import MobileCoreServices
import MediaPlayer
import Photos

class MergeVideoViewController: UIViewController {
  var firstAsset: AVAsset?
  var secondAsset: AVAsset?
  var audioAsset: AVAsset?
  var loadingAssetOne = false
  
  @IBOutlet var activityMonitor: UIActivityIndicatorView!
  
  func savedPhotosAvailable() -> Bool {
    guard !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) else { return true }
    
    let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
    present(alert, animated: true, completion: nil)
    return false
  }
  
  @IBAction func loadAssetOne(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = true
      VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
  }
  
  @IBAction func loadAssetTwo(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = false
      VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
  }
  
  @IBAction func loadAudio(_ sender: AnyObject) {
    let mediaPickerController = MPMediaPickerController(mediaTypes: .any)
    mediaPickerController.delegate = self
    mediaPickerController.prompt = "Select audio"
    present(mediaPickerController, animated: true)
  }
    
  @IBAction func merge(_ sender: AnyObject) {
    guard let firstAsset = firstAsset, let secondAsset = secondAsset else { return }
    
    activityMonitor.startAnimating()
    
    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    let mixComposition = AVMutableComposition()
    
    // 2. create 2 video tracks
    let trackId = Int32(kCMPersistentTrackID_Invalid)
    guard let firstTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: trackId) else { return }
    
    do {
      let timeRange = CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
      let track = firstAsset.tracks(withMediaType: .video).first!
      try firstTrack.insertTimeRange(timeRange, of: track, at: kCMTimeZero)
    } catch {
      assertionFailure("Failed to load first track")
      return
    }
    
    guard let secondTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: trackId) else { return }
    
    do {
      let timeRange = CMTimeRangeMake(kCMTimeZero, secondAsset.duration)
      let track = secondAsset.tracks(withMediaType: .video).first!
      try secondTrack.insertTimeRange(timeRange, of: track, at: firstAsset.duration)
    } catch {
      assertionFailure("Failed to load second track")
      return
    }
    
    // 2.1
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero,
                                                CMTimeAdd(firstAsset.duration, secondAsset.duration))
    
    // 2.2
    let firstInstruction = VideoHelper.videoCompositionInstruction(firstTrack, asset: firstAsset)
    firstInstruction.setOpacity(0.0, at: firstAsset.duration)
    let secondInstruction = VideoHelper.videoCompositionInstruction(secondTrack, asset: secondAsset)
    
    // 2.3
    mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
    let mainComposition = AVMutableVideoComposition()
    mainComposition.instructions = [mainInstruction]
    mainComposition.frameDuration = CMTimeMake(1, 30)
    mainComposition.renderSize = CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    
    // 3. Audio track
    if let loadedAudioAsset = audioAsset {
      let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)
      do {
        let duration = CMTimeAdd(firstAsset.duration, secondAsset.duration)
        let timeRange = CMTimeRangeMake(kCMTimeZero, duration)
        let track = loadedAudioAsset.tracks(withMediaType: .audio).first!
        try audioTrack?.insertTimeRange(timeRange, of: track, at: kCMTimeZero)
      } catch {
        assertionFailure("Failed to load audio track")
        return
      }
    }
    
    // 4. Get path
    guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
    let date = dateFormatter.string(from: Date())
    let url = documentDirectory.appendingPathComponent("mergedVideo-\(date).mov")
    
    // 5. Create explorer
    guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
    exporter.outputURL = url
    exporter.outputFileType = .mov
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = mainComposition
    
    // TODO: Check for proper `exporter` retain and for retain cycles
    // 6. Perform the export
    exporter.exportAsynchronously { [weak self, exporter] in
      DispatchQueue.main.async { [weak exporter] in
        guard let `self` = self, let exporter = exporter else {
          return
        }
        self.exportDidFinish(exporter)
      }
    }
  }
  
  // MARK: - Private methods
  
  private func exportDidFinish(_ session: AVAssetExportSession) {
    // cleanup assets
    activityMonitor.stopAnimating()
    firstAsset = nil
    secondAsset = nil
    audioAsset = nil
    
    guard (session.status == .completed), let outputURL = session.outputURL
      else { return }
    
    let saveVideoToPhotos = { [weak self] in
      let changesBlock: ()->() = {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
      }
      let completion = { (saved: Bool, error: Error?) in
        guard let `self` = self else { return }
        
        let success = saved && (error == nil)
        let title = success ? "Success" : "Error"
        let message = success ? "Video saved" : "Failed to save video"
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .cancel)
        alert.addAction(ok)
        
        self.present(alert, animated: false)
      }
      PHPhotoLibrary.shared().performChanges(changesBlock, completionHandler: completion)
    } // end saveVideoToPhotos closure
    
    if PHPhotoLibrary.authorizationStatus() == .authorized {
      saveVideoToPhotos()
    } else {
      PHPhotoLibrary.requestAuthorization { (status) in
        if status == .authorized { saveVideoToPhotos() }
      } // end requestAuthorization closure
    } // end else block
  }// end exportDidFinish method
  
}

extension MergeVideoViewController: UIImagePickerControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    dismiss(animated: true, completion: nil)
    
    guard let mediaType = info[UIImagePickerControllerMediaType] as? String,
      mediaType == (kUTTypeMovie as String),
      let url = info[UIImagePickerControllerMediaURL] as? URL
      else { return }
    
    let avAsset = AVAsset(url: url)
    var message = ""
    if loadingAssetOne {
      message = "Video one loaded"
      firstAsset = avAsset
    } else {
      message = "Video two loaded"
      secondAsset = avAsset
    }
    let alert = UIAlertController(title: "Asset Loaded", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
    present(alert, animated: true, completion: nil)
  }
  
}

extension MergeVideoViewController: UINavigationControllerDelegate {
  
}

extension MergeVideoViewController: MPMediaPickerControllerDelegate {
  
  func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
    let completion = { [weak self] in
      guard let `self` = self else { return }
      
      let selectedSongs = mediaItemCollection.items
      guard let song = selectedSongs.first else { return }
      
      let url = song.value(forProperty: MPMediaItemPropertyAssetURL) as? URL
      let isURLMiss = (url == nil)
      self.audioAsset =  isURLMiss ? nil : AVAsset(url: url!)
      let title = isURLMiss ? "Asset not available" : "Asset Loaded"
      let message = isURLMiss ? "Audio not loaded" : "Audio Loaded"
      
      let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
      let ok = UIAlertAction(title: "OK", style: .cancel)
      alert.addAction(ok)
      
      self.present(alert, animated: true)
    }
    
    dismiss(animated: true, completion: completion)
  }

  func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    dismiss(animated: true)
  }
}
