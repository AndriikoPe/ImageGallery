//
//  ImageGalleries.swift
//  ImageGallery
//
//  Created by Пермяков Андрей on 3/8/19.
//  Copyright © 2019 Пермяков Андрей. All rights reserved.
//

import Foundation

struct Gallery: Codable {
    
    var imageURLs: [URL]
    var imageAspectRatios: [Float]
    
    var json: Data? {
        return try? JSONEncoder().encode(self)
    }
    
    init(_ urls: [URL], _ ratios: [Float]) {
        imageURLs = urls
        imageAspectRatios = ratios
    }
    
    init? (json: Data) {
        if let newValue = try? JSONDecoder().decode(Gallery.self, from: json) {
            self = newValue
        } else {
            return nil
        }
    }
}
