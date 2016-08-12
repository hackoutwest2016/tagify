//
//  MapViewController.swift
//  moments
//
//  Created by Pak on 09/08/16.
//  Copyright © 2016 paksnicefriends. All rights reserved.
//
// Discover new songs on a map view

import UIKit
import Mapbox



class DiscoverViewController: UIViewController, MGLMapViewDelegate {
    
    @IBOutlet weak var addButton: UIButton!
    
    var selectedParseId = ""
    
    var mapView = MGLMapView()
    
    var momentTags: [PFObject] = []
    
    let locationManager = CLLocationManager()
    
    @IBAction func addButtonTapped(sender: UIButton) {
        
        performSegueWithIdentifier("moveToSearch", sender: sender)
    }
    
    override func viewDidLayoutSubviews() {
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setStyle()
        trackUser()
        view.addSubview(mapView)
        
        // Set the map view‘s delegate property.
        mapView.delegate = self
        
        
        view.sendSubviewToBack(mapView)
        
        let timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(pollForTags), userInfo: nil, repeats: true)
        
        
        
    }
    
    
    func createMarker(chosenImg:UIImage) -> UIImage{
        // the chosen image
        
        var roundedImg = resizeImage(chosenImg)
        roundedImg = maskRoundedImage(roundedImg, radius: 40)
        
        let drop = UIImage(named: "drop")!
        let combined = combineImages(drop, topImage: roundedImg)
        
        return combined
    }
    
    
    func combineImages(bottomImage:UIImage, topImage:UIImage) -> UIImage {
        
        //let newSize = CGSizeMake(100, 100) // set this to what you need
        UIGraphicsBeginImageContextWithOptions(bottomImage.size, false, 2.0)
        
        bottomImage.drawInRect(CGRect(origin: CGPointZero, size: bottomImage.size))
        topImage.drawInRect(CGRect(origin: CGPointMake(10, 10), size: topImage.size))
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    
    
    
    func pollForTags() {
        //Find all tags in database
        //Exclude already found tags
        var predicate: NSPredicate? = nil
        if momentTags.count > 0 {
            var objectIds: [String] = []
            for momentTag in momentTags {
                objectIds.append(momentTag.objectId!)
                
                //print("not equal to \(momentTag.objectId!)")
            }
            predicate = NSPredicate(format: "NOT (objectId IN %@)", objectIds)
        }
        
        let query = PFQuery(className: "MomentTag", predicate: predicate)
        
        query.findObjectsInBackgroundWithBlock {
            (newMomentTags: [PFObject]?, error: NSError?) -> Void in
            if error != nil {
                print("Error: \(error!) \(error!.userInfo)")
            } else if var newMomentTags = newMomentTags {
                if newMomentTags.count > 0 {
                    print("Found \(newMomentTags.count) new tags.")
                    self.momentTags += newMomentTags
                    
                    for momentTag in newMomentTags {
                        if let position = momentTag["position"] as? PFGeoPoint {
                            let annotation = MGLPointAnnotation()
                            annotation.coordinate = CLLocationCoordinate2DMake(position.latitude, position.longitude)
                            annotation.title = momentTag.objectId!
                            
                            self.mapView.addAnnotation(annotation)
                        }
                    }
                }
            }
        }
    }
    
    
    func getUserLocation() -> CLLocationCoordinate2D {
        let location = MGLUserLocation()
        return location.coordinate
    }
    
    func setStyle() {
        
        // 20 is max
        mapView.setZoomLevel(16, animated: false)
        let styleURL = NSURL(string: MomentsConfig.mapbox.styleUrl)
        mapView = MGLMapView(frame: view.bounds, styleURL: styleURL)
        mapView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        view.addSubview(mapView)
        
        
    }
    
    func trackUser() {
        mapView.userTrackingMode = MGLUserTrackingMode.Follow
        
    }
    
    
    func mapView(mapView: MGLMapView, viewForAnnotation annotation: MGLAnnotation) -> MGLAnnotationView? {
        // This example is only concerned with point annotations.
        guard annotation is MGLPointAnnotation else {
            return nil
        }
        //new lines
        
        
        
        
        // Use the point annotation’s longitude value (as a string) as the reuse identifier for its view.
        let reuseIdentifier = "\(annotation.coordinate.longitude)"
        
        // For better performance, always try to reuse existing annotations.
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseIdentifier)
        
        // the annotation.title was previously set to be the objectId of moment tag object
        let objectId = annotation.title!
        
        //Find corresponding moment tag
        
        //Find the index
        if let momentTagIndex = momentTags.indexOf({$0.objectId == objectId}) {
            let momentTag = momentTags[momentTagIndex]
            
            
            // If there’s no reusable annotation view available, initialize a new one.
            if annotationView == nil {
                
                if let thumbnailFile = momentTag["thumbnail"] as? PFFile {
                    if thumbnailFile.dataAvailable {
                        if let data = try? thumbnailFile.getData() {
                            var thumbnail = UIImage(data:data, scale: 2.0)
                            // make it rounded
                            thumbnail = maskRoundedImage(thumbnail!, radius: Float((thumbnail?.size.height)!/2))
                            
                            //size of images
                            let imageSize:CGFloat = 60
                            let borderWidth:CGFloat = 0
                            let totalSize:CGFloat = borderWidth+imageSize
                            
                            let thumbnailView = UIImageView(frame: CGRectMake(borderWidth/2, borderWidth/2, 0, 0))
                            thumbnailView.image = thumbnail
                            print(thumbnailView.center)
                            thumbnailView.center = CGPoint(x: imageSize/2, y: imageSize/2)
                            print(thumbnailView.center)
                            
                            annotationView = CustomAnnotationView(reuseIdentifier: reuseIdentifier)
                            annotationView!.frame = CGRectMake(0, 0, totalSize, totalSize)
                            
                            annotationView?.addSubview(thumbnailView)
                            //annotationView!.backgroundColor = Palette.purple
                            
                            
                            let randomDelay = arc4random_uniform(5)
                         
                            UIView.animateWithDuration(10, delay: NSTimeInterval(0 ) , usingSpringWithDamping: 0.2, initialSpringVelocity: 1, options: UIViewAnimationOptions.CurveEaseInOut, animations: {
                                thumbnailView.frame.size = CGSize(width: imageSize, height: imageSize)
                         
                                
                                }, completion: nil)
                            
                        }
                    }
                }
            }
        }
        
        return annotationView
    }
    
    func mapView(mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Always allow callouts to popup when annotations are tapped.
        return false
    }
    
    func mapView(mapView: MGLMapView, didSelectAnnotation annotation: MGLAnnotation) {
        print("seelected")
        selectedParseId = annotation.title!!
        performSegueWithIdentifier("moveToViewSong", sender: nil)
        
        
    }
    
    
    
    
    func resizeImage(image:UIImage) -> UIImage
    {
        var actualHeight:Float = Float(image.size.height)
        var actualWidth:Float = Float(image.size.width)
        
        let maxHeight:Float = 40.0 //your choose height
        let maxWidth:Float = 40.0  //your choose width
        
        var imgRatio:Float = actualWidth/actualHeight
        let maxRatio:Float = maxWidth/maxHeight
        
        if (actualHeight > maxHeight) || (actualWidth > maxWidth)
        {
            if(imgRatio < maxRatio)
            {
                imgRatio = maxHeight / actualHeight;
                actualWidth = imgRatio * actualWidth;
                actualHeight = maxHeight;
            }
            else if(imgRatio > maxRatio)
            {
                imgRatio = maxWidth / actualWidth;
                actualHeight = imgRatio * actualHeight;
                actualWidth = maxWidth;
            }
            else
            {
                actualHeight = maxHeight;
                actualWidth = maxWidth;
            }
        }
        
        let rect:CGRect = CGRectMake(0.0, 0.0, CGFloat(actualWidth) , CGFloat(actualHeight) )
        //UIGraphicsBeginImageContext(rect.size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 2.0)
        image.drawInRect(rect)
        
        let img:UIImage = UIGraphicsGetImageFromCurrentImageContext()
        let imageData:NSData = UIImageJPEGRepresentation(img, 1.0)!
        UIGraphicsEndImageContext()
        
        return UIImage(data: imageData)!
    }
    
    func maskRoundedImage(image: UIImage, radius: Float) -> UIImage {
        let imageView: UIImageView = UIImageView(image: image)
        var layer: CALayer = CALayer()
        layer = imageView.layer
        
        layer.masksToBounds = true
        layer.cornerRadius = CGFloat(radius)
        
        UIGraphicsBeginImageContext(imageView.bounds.size)
        layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let roundedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return roundedImage
    }
    
    func scaleUIImageToSize(let image: UIImage, let size: CGSize) -> UIImage {
        let hasAlpha = false
        let scale: CGFloat = 2.0 // Automatically use scale factor of main screen
        
        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        image.drawInRect(CGRect(origin: CGPointZero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    
    func resizeImage2(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / image.size.width
        let heightRatio = targetSize.height / image.size.height
        
        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSizeMake(size.width * heightRatio, size.height * heightRatio)
        } else {
            newSize = CGSizeMake(size.width * widthRatio,  size.height * widthRatio)
        }
        
        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRectMake(0, 0, newSize.width, newSize.height)
        
        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 2.0)
        image.drawInRect(rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "moveToSearch"
        {
            if let destinationVC = segue.destinationViewController as? SearchViewController {
                destinationVC.userCoordinate = mapView.userLocation?.coordinate
                print("userCoordinate: \(mapView.userLocation?.coordinate)")
                
            }
        }
        
        if segue.identifier == "moveToViewSong"
        {
            if let destinationVC = segue.destinationViewController as? SongViewController {
                if selectedParseId != "" {
                    for momentTag in momentTags {
                        
                        if momentTag.objectId == selectedParseId {
                            
                            //spotify URI
                            var spotifyUrl = momentTag["spotifyUrl"] as? String
                            if (spotifyUrl == nil){
                                spotifyUrl = "0EFEkt29P7Icr7dO4vN6yk"
                            }
                            
                            var spotifySong = Song(artist: "Test", name: "Test", link: spotifyUrl!)
                            
                            SPTTrack.trackWithURI(NSURL(string: "spotify:track:"+spotifyUrl!), session: nil, callback: { (error, data) in
                                
                                if let track = data as? SPTTrack{
                                    print(track)
                                    print(track.artists.first)
                                    print(track.name)
                                    
                                    let artist =  "\((track.artists.first as! SPTPartialArtist).name)"
                                    let name = track.name
                                    spotifySong = Song(artist: artist, name: name, link: spotifyUrl!)
                                    
                                    print("spotifySong: \(spotifySong)")
                                    
                                    destinationVC.spotifySong = spotifySong
                                    destinationVC.momentTag = momentTag
                                }
                            })
                            
                            
                            
                        }
                        
                    }
                }
                
            }
        }
        
    }
    
    
    @IBAction func backButton(sender: UIStoryboardSegue) {
        //TODO: Return
        /*if let previousVS = sender.sourceViewController as? SongViewController {
         if let momentTagIndex = momentTags.indexOf({$0.objectId == previousVS.momentTag?.objectId}) {
         let momentTag = momentTags[momentTagIndex]
         
         if let annotationIndex = mapView.annotations!.indexOf({$0.title! == momentTag.objectId}) {
         let annotation = mapView.annotations![annotationIndex]
         
         mapView.removeAnnotation(annotation)
         mapView.addAnnotation(annotation)
         //TODO POP animation
         }
         }
         }*/
        //performSegueWithIdentifier("unwindSegue1", sender: self)
    }
}


class CustomAnnotationView: MGLAnnotationView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Force the annotation view to maintain a constant size when the map is tilted.
        scalesWithViewingDistance = true
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.cornerRadius = frame.width / 2
//        layer.borderWidth = 3
//        layer.borderColor = Palette.purple.CGColor
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Animate the border width in/out, creating an iris effect.
        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.1
        layer.borderWidth = selected ? frame.width / 4 : 2
        layer.addAnimation(animation, forKey: "borderWidth")
    }
}


