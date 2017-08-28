//
//  ViewController.swift
//  ImagePerformanceOptimization
//
//  Created by 王红庆 on 2017/5/21.
//  Copyright © 2017年 王红庆. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let image = UIImage(named: "avatar_default")
//        let image = UIImage(named: "avatar.jpeg")
        
        for _ in 0..<100 {
            
            let imageView01 = UIImageView(frame: CGRect(x: 100, y: 100, width: 160, height: 160))
            imageView01.image = image
            view.addSubview(imageView01)
            
            let rect02 = CGRect(x: 100, y: 300, width: 160, height: 160)
            let imageView02 = UIImageView(frame: rect02)
//            imageView02.image = avatarImage(image: image!, size: rect02.size, backColor: view.backgroundColor)
            view.addSubview(imageView02)
            
            // 封装的方法
//            imageView02.image = image?.hq_rectImage(size: rect02.size)
            imageView02.image = image?.hq_avatarImage(size: rect02.size)
        }
    }
}

/**************************************** 下面是练习的DEMO ****************************************/
extension ViewController {
    
    /// 将给定的图像进行拉伸,并且返回新的图像
    ///
    /// - Parameters:
    ///   - image: 原图
    ///   - size: 目标尺寸
    /// - Returns: 返回一个新的'目标尺寸'的图像
    func avatarImage(image: UIImage, size: CGSize, backColor:UIColor?) -> UIImage? {
        
        let rect = CGRect(origin: CGPoint(), size: size)
        
        // 1.图像的上下文-内存中开辟一个地址,跟屏幕无关
        /**
         * 1.绘图的尺寸
         * 2.不透明:false(透明) / true(不透明)
         * 3.scale:屏幕分辨率,默认情况下生成的图像使用'1.0'的分辨率,图像质量不好
         *         可以指定'0',会选择当前设备的屏幕分辨率
         */
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        
        // 背景填充(在裁切之前做填充)
        backColor?.setFill()
        UIRectFill(rect)
        
        // 1> 实例化一个圆形的路径
        let path = UIBezierPath(ovalIn: rect)
        // 2> 进行路径裁切 - 后续的绘图,都会出现在圆形路径内部,外部的全部干掉
        path.addClip()
        
        // 2.绘图'drawInRect'就是在指定区域内拉伸屏幕
        image.draw(in: rect)
        
        // 3.绘制内切的圆形
        UIColor.darkGray.setStroke()
        path.lineWidth = 5      // 默认是'1'
        path.stroke()
        
        // 4.取得结果
        let result = UIGraphicsGetImageFromCurrentImageContext()
        
        // 5.关闭上下文
        UIGraphicsEndImageContext()
        
        // 6.返回结果
        return result
    }
}
