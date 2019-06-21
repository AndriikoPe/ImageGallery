//
//  FullImageViewController.swift
//  ImageGallery
//
//  Created by Пермяков Андрей on 3/28/19.
//  Copyright © 2019 Пермяков Андрей. All rights reserved.
//

import UIKit

class FullImageViewController: UIViewController, UIScrollViewDelegate {
    
    override func viewDidAppear(_ animated: Bool) {
        imageView.image = nil
        super.viewDidAppear(true)
        if let url = imageURL {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let urlContents = try? Data(contentsOf: url)
                DispatchQueue.main.async {
                    if let imageData = urlContents, url == self?.imageURL {
                        self?.spinner?.stopAnimating()
                        self?.imageView.image = UIImage(data: imageData)
                    }
                }
            }
        }
        scrollView.contentSize = imageView.frame.size
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 2.0
        scrollView.delegate = self
        scrollView.contentSize = imageView.frame.size
    }
    
    
    var imageURL: URL!
    
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

}
