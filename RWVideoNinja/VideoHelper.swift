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
import AVFoundation

class VideoHelper {
  
  static func startMediaBrowser(delegate: UIViewController & UINavigationControllerDelegate & UIImagePickerControllerDelegate, sourceType: UIImagePickerControllerSourceType) {
    guard UIImagePickerController.isSourceTypeAvailable(sourceType) else { return }
    
    let mediaUI = UIImagePickerController()
    mediaUI.sourceType = sourceType
    mediaUI.mediaTypes = [kUTTypeMovie as String]
    mediaUI.allowsEditing = true
    mediaUI.delegate = delegate
    delegate.present(mediaUI, animated: true, completion: nil)
  }

  static func orientationFromTransform(_ transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
    var orientation: UIImageOrientation = .up
    var isPortrait = false
    
    switch (transform.a, transform.b, transform.c, transform.d) {
    case (0, 1, -1, 0) :
      orientation = .right
      isPortrait = true
      
    case (0, -1, 1, 0):
      orientation = .left
      isPortrait = true
      
    case (1, 0, 0, 1):
      orientation = .up
      
    case (-1, 0, 0, -1):
      orientation = .down
      
    default:
      break
    }
    
    return (orientation, isPortrait)
  }
  
  static func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
    let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    let assetTrack = asset.tracks(withMediaType: .video).first!
    
    let transform = assetTrack.preferredTransform
    let assetInfo = orientationFromTransform(transform)
    
    var scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.width
    if assetInfo.isPortrait {
      scaleToFitRatio = UIScreen.main.bounds.width / assetTrack.naturalSize.height
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      let transform = assetTrack.preferredTransform.concatenating(scaleFactor)
      instruction.setTransform(transform, at: kCMTimeZero)
    }
    else {
      let scaleFactor = CGAffineTransform(scaleX: scaleToFitRatio, y: scaleToFitRatio)
      let yTranslation = UIScreen.main.bounds.width / 2
      var concat = assetTrack.preferredTransform
        .concatenating(scaleFactor)
        .concatenating(CGAffineTransform(translationX: 0, y: yTranslation))
      
      if assetInfo.orientation == .down {
        let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        let windowBounds = UIScreen.main.bounds
        let yFix = assetTrack.naturalSize.height + windowBounds.height
        let centerFix = CGAffineTransform(translationX: assetTrack.naturalSize.width, y: yFix)
        concat = fixUpsideDown.concatenating(centerFix).concatenating(scaleFactor)
      }
      
      instruction.setTransform(concat, at: kCMTimeZero)
    }

    return instruction
  }

}
