//
//  Document.swift
//  ImageGallery
//
//  Created by Пермяков Андрей on 6/2/19.
//  Copyright © 2019 Пермяков Андрей. All rights reserved.
//

import UIKit

class ImageGalleryDocument: UIDocument {
    
    var imageGallery: Gallery?
    
    override func contents(forType typeName: String) throws -> Any {
        return imageGallery?.json ?? Data()
    }
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        if let json = contents as? Data {
            imageGallery = Gallery(json: json)
        }
    }
}

