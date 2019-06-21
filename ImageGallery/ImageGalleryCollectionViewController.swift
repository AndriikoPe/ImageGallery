//
//  ImageGalleryViewController.swift
//  ImageGallery
//
//  Created by Пермяков Андрей on 2/12/19.
//  Copyright © 2019 Пермяков Андрей. All rights reserved.
//

import UIKit

class ImageGalleryCollectionViewController: UICollectionViewController, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UICollectionViewDelegateFlowLayout {
    
    var imageGallery: Gallery? {
        get {
            if imageURLs.count != 0 {
                return Gallery(imageURLs, imageAspectRatio)
            } 
            return nil
        }
        set {
            if let gallery = newValue {
                imageURLs = gallery.imageURLs
                imageAspectRatio = gallery.imageAspectRatios
            }
        }
    }
    
    private var cache = URLCache.shared
    private var session = URLSession(configuration: .default)
    
    var imageURLs = [URL]()
    var imageAspectRatio = [Float]() //  height / width

    private var cellWidth: CGFloat = 400
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cache = URLCache(memoryCapacity: 4 * 1024 * 1024, diskCapacity: 10 * 1024 * 1024, diskPath: nil)
        
        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(ImageGalleryCollectionViewController.resizeCells))
        collectionView.addGestureRecognizer(pinchGestureRecognizer)
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true
    }
    
    var document: ImageGalleryDocument?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        document?.open { success in
            if success {
                self.title = self.document?.localizedName
                self.imageGallery = self.document?.imageGallery
                self.collectionView.reloadData()
            }
        }
    }
    
    @IBAction func close(_ sender: UIBarButtonItem) {
        presentingViewController?.dismiss(animated: true) {
            self.document?.close()
        }
    }
    
    func documentChanged(_ sender: UIBarButtonItem? = nil) {
        document?.imageGallery = imageGallery
        print("Saved successfully")
        if document?.imageGallery != nil {
            document?.updateChangeCount(.done)
        }
    }
    
    //MARK: Gestures
    
    @objc private func resizeCells(recognizer: UIPinchGestureRecognizer) {
        if imageURLs.count > 0 {
            if recognizer.state == .began || recognizer.state == .changed {
                let scale = recognizer.scale
                if scale < 1 {
                    cellWidth -= scale * 4 // (* 4) just to make it faster & nicer
                } else {
                    cellWidth += scale * 4
                }
                recognizer.scale = 1.0
                flowLayout?.invalidateLayout()
            }
        }
    }
    
    private var flowLayout: UICollectionViewFlowLayout? {
        return collectionView?.collectionViewLayout as? UICollectionViewFlowLayout
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: cellWidth, height: collectionView.bounds.height)
    }
    
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let imageVC = segue.destination.contents as? FullImageViewController {
            imageVC.imageURL = sender as? URL
        }
    }
 

    // MARK: UICollectionViewDataSource

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }


    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageURLs.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath)
        if let imageCell = cell as? ImageGalleryCollectionViewCell {
            imageCell.imageView.image = nil
            
            let url = imageURLs[indexPath.item]
            let request = URLRequest(url: url.imageURL)
            
            if let cacheResponse = cache.cachedResponse(for: request), let image = UIImage(data: cacheResponse.data) { // cache exists
                let sizedImage = image.resize(width: imageCell.bounds.width, height: CGFloat(imageAspectRatio[indexPath.item]) * imageCell.bounds.width)
                imageCell.imageView.image = sizedImage
            } else { // cache doesn't exist
                imageCell.spinner.startAnimating()
                DispatchQueue.global(qos: .userInitiated).async { [weak self, weak imageCell] in
                    let task = self?.session.dataTask(with: request) { (urlData, urlResponse, urlError) in
                        DispatchQueue.main.async {
                            if urlError != nil {
                                print("Failed to load image with error: \(String(describing: urlError))")
                            }
                            if let data = urlData, let image = UIImage(data: data) {
                                if let response = urlResponse {
                                    self?.cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
                                }
                                imageCell?.spinner.stopAnimating()
                                imageCell?.imageView.image = image
                            } else {
                                imageCell?.spinner.stopAnimating()
                                imageCell?.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.01176470611, blue: 0.5607843399, alpha: 1)
                            }
                        }
                    }
                    task?.resume()
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        if let image = (collectionView.cellForItem(at: indexPath) as? ImageGalleryCollectionViewCell)?.imageView.image {
            let dragItem = UIDragItem(itemProvider: NSItemProvider(object: image))
            dragItem.localObject = image
            return [dragItem]
        } else {
            return []
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSURL.self) ||  session.canLoadObjects(ofClass: UIImage.self)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
        return UICollectionViewDropProposal(operation: isSelf ? .move : .copy,  intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: imageURLs.count, section: 0)
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                if (item.dragItem.localObject as? UIImage) != nil {
                    collectionView.performBatchUpdates({
                        let movedURL = self.imageURLs.remove(at: sourceIndexPath.item)
                        self.imageURLs.insert(movedURL, at: destinationIndexPath.item)
                        let movedAspectRatio = self.imageAspectRatio.remove(at: sourceIndexPath.item)
                        self.imageAspectRatio.insert(movedAspectRatio, at: destinationIndexPath.item)
                        collectionView.deleteItems(at: [sourceIndexPath])
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                    self.documentChanged()
                }
            } else {
                coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                item.dragItem.itemProvider.loadObject(ofClass: UIImage.self) { (provider, error) in
                    if let image = provider as? UIImage {
                        let width = image.size.width
                        let height = image.size.height
                        self.imageAspectRatio.insert(Float(height / width), at: destinationIndexPath.item)
                        self.documentChanged()
                    }
                }
                item.dragItem.itemProvider.loadObject(ofClass: NSURL.self) { (provider, error) in
                    if let url = provider as? URL {
                        let correctURL = url.imageURL
                        self.imageURLs.insert(correctURL, at: destinationIndexPath.item)
                        DispatchQueue.main.async {
                            collectionView.insertItems(at: [destinationIndexPath])
                        }
                        self.documentChanged()
                    }
                }
               
            }
        }
    }
    
    
    
    

    // MARK: UICollectionViewDelegate

    /*
    // Uncomment this method to specify if the specified item should be highlighted during tracking
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let url = imageURLs[indexPath.item]
        self.performSegue(withIdentifier: "showFullImage", sender: url)
    }
    
    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}


extension UIImage {
    func resize(width: CGFloat, height: CGFloat) -> UIImage? {
        let size = CGSize(width: width, height: height)
        let rect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
}
