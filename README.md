# ImagePerformanceOptimization
Swift 版本图像性能优化

![](http://upload-images.jianshu.io/upload_images/2069062-71f45a10b6969e90.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

## 前言

> 随着移动端的发展，现在越来越注重性能优化了。这篇文章将谈一谈对于图片的性能优化。面试中又会经常有这样的问题：如何实现一个图像的圆角，不要用`cornerRadius`?

---

## 模拟器常用性能测试工具

#### Color Blended Layers(混合图层->检测图像的混合模式)

- 此功能基于渲染程度对屏幕中的混合区域进行**绿->红**的高亮(也就是多个半透明层的叠加，其中绿色代表比较好，红色则代表比较糟糕)
- 由于重绘的原因，混合对[**GPU**](http://baike.baidu.com/link?url=plmxpuyqzgINDIhjGlN1Cru9Mk5mz4m3KbPO3nnwf2itsSsxWUHdrlQ9qTghBADJRJj0JPK5mUXteC5n7vtuMD8HOGE6B5fNIsY5pq9KsFNEwhAYOZMQ94vy10Gk3cX_033fcgr3SeCPFjeVvPNnBHSFmPD2MA3Hj1M0M13xg0j9RuTstmTBykDFxy316p8b)(*Graphics Processing Unit->专门用来画图的*)性能会有影响，同时也是滑动或者动画帧率下降的罪魁祸首之一

> GPU：如果有透明的图片叠加，做两个图像透明度之间叠加的运算，运算之后生成一个结果，显示到屏幕上，如果透明的图片叠加的很多，运算量就会很大
>
> `png`格式的图片是透明的，如果边上有无色的地方，那么可以把底下的背景透过来
>
> 一般指定颜色的时候不建议使用透明色，透明色执行效率低

#### Color Copied Images(图像复制->几乎用不到)

- 有时候`寄宿图片(layer.content)`的生成是由`Core Animation`被强制生成一些图片，然后发送到渲染服务器，而不是简单的指向原始指针
- 这个选项把这些图片渲染成蓝色
- 复制图片对内存和**CPU**使用来说都是一项非常昂贵的操作，所以应该尽可能的避免

#### Color Misaligned Images(拉伸图像->检测图片有没有被拉伸)

- 会高亮那些被缩放或者拉伸以及没有正确对齐到像素边界的图片(也就是非整型坐标)
- 通常都会导致图片的不正常缩放，比如把一张大图当缩略图显示，或者不正确的模糊图像

如果图片做**拉伸**的动作，是消耗**CPU**的。如果图片显示在一个`Cell`上面，滚出屏幕再滚动回来的时候，图片仍然需要重新被设置，在进入屏幕之前还需要一次**拉伸操作**，这些**拉伸**的操作是会消耗**CPU**的计算的。这样的设置多了以后就会严重影响性能。一个图片是否被进行了**拉伸操作**，我们用模拟器就可以判断出来。

---

## 为什么我们说这种方法设置图像效果不好

#### Color Misaligned Images(拉伸图像->检测图片有没有被拉伸)

创建一个自定义尺寸的`ImageView`，并设置图像

```swift
let image = UIImage(named: "avatar_default")

let imageView01 = UIImageView(frame: CGRect(x: 100, y: 100, width: 160, height: 160))
imageView01.image = image
view.addSubview(imageView01)
```

![](http://upload-images.jianshu.io/upload_images/2069062-7f3b49227fc4d4fe.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

图片在模拟器上的显示

![](http://upload-images.jianshu.io/upload_images/2069062-4392392fb941b9f8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/375)

利用模拟器的`Debug`的`Color Misaligned Images`功能查看图片状态。如下图所示，图片显示黄色，证明图片被拉伸了。

![](http://upload-images.jianshu.io/upload_images/2069062-c6d1e15e2c3ad439.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

就知道你可能会不相信，继续看！将`ImageView`的尺寸设置成和图片一样大小，再利用模拟器`Color Misaligned Images`功能再次查看图片状态。结果如图所示

![](http://upload-images.jianshu.io/upload_images/2069062-ddea3cdb34dc3c9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 事实证明，如果图像尺寸和`ImageView`尺寸不一致，图像就一定会被拉伸，只要被拉伸，**CPU**就会工作，如果是在`cell`上，每次`cell`离开屏幕再回到屏幕的时候，都会对图片进行拉伸处理。就会频繁的消耗**CPU**从而导致影响`APP`的性能。

#### Color Offscreen-Rendered(离屏渲染->有待完善)

- 这里会把那些需要离屏渲染的图层高亮成黄色
- 这些图层很可能需要用`shadownPath`或者`shouldRasterize(栅格化)`来优化

> 好处：图像提前生成
>
> 坏处：**CPU**和**GPU**会频繁的切换，会导致**CPU**的消耗会高一点，但是性能会提升

#### 小结：

> - 以上性能优化中，有效的检测`Color Blended Layers`和`Color Misaligned Images`在开发中能够提升图像的性能
> - `Color Copied Images`几乎遇不到
> - `Color Offscreen-Rendered`主要用于`cell`的性能优化

---

## 解决图片拉伸问题

#### 利用核心绘图功能实现，根据尺寸获取路径，重新绘制一个目标尺寸的图片

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    
    let image = UIImage(named: "avatar_default")
    
    let imageView01 = UIImageView(frame: CGRect(x: 100, y: 100, width: 160, height: 160))
    imageView01.image = image
    view.addSubview(imageView01)
    
    let rect = CGRect(x: 100, y: 300, width: 160, height: 160)
    let imageView02 = UIImageView(frame: rect)
    
    // 自定义创建图像的方法
    imageView02.image = avatarImage(image: image!, size: rect.size)
    view.addSubview(imageView02)
    
}
```

自定义创建图像的方法

```swift
/// 将给定的图像进行拉伸,并且返回新的图像
///
/// - Parameters:
///   - image: 原图
///   - size: 目标尺寸
/// - Returns: 返回一个新的'目标尺寸'的图像
func avatarImage(image: UIImage, size: CGSize) -> UIImage? {
    
    let rect = CGRect(origin: CGPoint(), size: size)
    
    // 1.图像的上下文-内存中开辟一个地址,跟屏幕无关
    /**
     * 1.绘图的尺寸
     * 2.不透明:false(透明) / true(不透明)
     * 3.scale:屏幕分辨率,默认情况下生成的图像使用'1.0'的分辨率,图像质量不好
     *         可以指定'0',会选择当前设备的屏幕分辨率
     */
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
    
    // 2.绘图'drawInRect'就是在指定区域内拉伸屏幕
    image.draw(in: rect)
    
    // 3.取得结果
    let result = UIGraphicsGetImageFromCurrentImageContext()
    
    // 4.关闭上下文
    UIGraphicsEndImageContext()
    
    // 5.返回结果
    return result
}
```

效果如下

![](http://upload-images.jianshu.io/upload_images/2069062-16735447bc8015d9.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/375)

如果到这里你以为就完事了，那你真是太年轻了

![](http://upload-images.jianshu.io/upload_images/2069062-9f23d6bfe19bbdc9.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 再解决混合模式`(Color Blended Layers)`问题

继续刚才的话题，仅仅解决了拉伸问题后，在`Color Blended Layers(混合模式)`下还是有问题，如图

![](http://upload-images.jianshu.io/upload_images/2069062-557e12e83e0d7a87.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/375)

将绘图选项的透明状态设置为**不透明(true)**

![](http://upload-images.jianshu.io/upload_images/2069062-a2db1facaf4c74ce.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

到这里，如果类似新闻`APP`图片都只是显示方形的，就可以搞定了。那如果是头像怎么办呢？头像绝大多数都是圆角头像，而且现在越来越多的考虑到性能方面的问题。很多人都不用`cornerRadius`，认为用`cornerRadius`不是一个好的解决办法。

#### 设置图像圆角，不用`cornerRadius`

在`获取上下文(UIGraphicsBeginImageContextWithOptions)`和`绘图(drawInRect)`之间实例化一个圆形的路径，并进行路径裁切

```swift
// 1> 实例化一个圆形的路径
let path = UIBezierPath(ovalIn: rect)
// 2> 进行路径裁切 - 后续的绘图,都会出现在圆形路径内部,外部的全部干掉
path.addClip()
```

效果如下

![](http://upload-images.jianshu.io/upload_images/2069062-d245aad5d97920bb.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> `UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)`这里选择了`true(不透明)`，四个角即使被裁切掉（没有在获取到的路径里面）但是由于是`不透明`的模式，所以看不到下面的颜色，默认看到了黑色的背景。

将`UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)`透明模式改为`false(透明)`

![](http://upload-images.jianshu.io/upload_images/2069062-6cd49561b9505748.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/375)

再看下混合模式，四个叫和头像都是红色，并且颜色深浅程度不一样，越红效率越不好。证明有图层叠加的运算，因此，不能采用透明的模式。

![](http://upload-images.jianshu.io/upload_images/2069062-a7383d486748f594.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/375)

解决办法：给背景设置一个颜色，使其不显示默认的黑色。
这样就可以解决四个角显示黑色的问题，并且在混合模式状态下不会再有红色显示，性能可以非常的好。

![](http://upload-images.jianshu.io/upload_images/2069062-65151e41ee3cd664.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 开发过程中，用颜色比用图片性能会高一点。
> 
> 不到万不得已，`View`的背景色尽量不要设置成透明颜色。

给图像添加边框，绘制内切的圆形

```swift
UIColor.darkGray.setStroke()
path.lineWidth = 5      // 默认是'1'
path.stroke()
```

![](http://upload-images.jianshu.io/upload_images/2069062-b81b4b104fe4e4dc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 判断一个应用程序的好坏，看图像处理的是否到位，如果表格里面图像都拉伸，并且设置`cornerRadius`，那么表格的卡顿可能将会变得非常明显。

下面是方法的最终代码：

```swift
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
```

---

## 封装

为了方便自己以后用，因此，将其封装起来。如果有更好的改进办法欢迎给我提出。

建立了一个空白文件`HQImage`，在`UIImage`的`extension`里面自定义了两个方法`创建头像图像(hq_avatarImage)`和`创建矩形图像(hq_rectImage)`

```swift
// MARK: - 创建图像的自定义方法
extension UIImage {
    
    /// 创建圆角图像
    ///
    /// - Parameters:
    ///   - size: 尺寸
    ///   - backColor: 背景色(默认`white`)
    ///   - lineColor: 线的颜色(默认`lightGray`)
    /// - Returns: 裁切后的图像
    func hq_avatarImage(size: CGSize?, backColor: UIColor = UIColor.white, lineColor: UIColor = UIColor.lightGray) -> UIImage? {
        
        var size = size
        
        if size == nil {
            size = self.size
        }
        
        let rect = CGRect(origin: CGPoint(), size: size!)
        
        // 1.图像的上下文-内存中开辟一个地址,跟屏幕无关
        /**
         * 1.绘图的尺寸
         * 2.不透明:false(透明) / true(不透明)
         * 3.scale:屏幕分辨率,默认情况下生成的图像使用'1.0'的分辨率,图像质量不好
         *         可以指定'0',会选择当前设备的屏幕分辨率
         */
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        
        // 背景填充(在裁切之前做填充)
        backColor.setFill()
        UIRectFill(rect)
        
        // 1> 实例化一个圆形的路径
        let path = UIBezierPath(ovalIn: rect)
        // 2> 进行路径裁切 - 后续的绘图,都会出现在圆形路径内部,外部的全部干掉
        path.addClip()
        
        // 2.绘图'drawInRect'就是在指定区域内拉伸屏幕
        draw(in: rect)
        
        // 3.绘制内切的圆形
        UIColor.darkGray.setStroke()
        path.lineWidth = 1      // 默认是'1'
        path.stroke()
        
        // 4.取得结果
        let result = UIGraphicsGetImageFromCurrentImageContext()
        
        // 5.关闭上下文
        UIGraphicsEndImageContext()
        
        // 6.返回结果
        return result
    }
    
    /// 创建矩形图像
    ///
    /// - Parameters:
    ///   - size: 尺寸
    ///   - backColor: 背景色(默认`white`)
    ///   - lineColor: 线的颜色(默认`lightGray`)
    /// - Returns: 裁切后的图像
    func hq_rectImage(size: CGSize?, backColor: UIColor = UIColor.white, lineColor: UIColor = UIColor.lightGray) -> UIImage? {
        
        var size = size
        
        if size == nil {
            size = self.size
        }
        
        let rect = CGRect(origin: CGPoint(), size: size!)
        
        // 1.图像的上下文-内存中开辟一个地址,跟屏幕无关
        /**
         * 1.绘图的尺寸
         * 2.不透明:false(透明) / true(不透明)
         * 3.scale:屏幕分辨率,默认情况下生成的图像使用'1.0'的分辨率,图像质量不好
         *         可以指定'0',会选择当前设备的屏幕分辨率
         */
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        
        // 2.绘图'drawInRect'就是在指定区域内拉伸屏幕
        draw(in: rect)
        
        // 3.取得结果
        let result = UIGraphicsGetImageFromCurrentImageContext()
        
        // 4.关闭上下文
        UIGraphicsEndImageContext()
        
        // 5.返回结果
        return result
    }
}
```

---

## 性能测试

没有对比就无从谈起性能优化，以下是我根据两种方法，循环创建`100`个`ImageView`的**CPU**和**内存**消耗（个人感觉`1`张图片不一定能说明问题，所以搞了`100`个）

#### 系统方法创建图像

```swift
for _ in 0..<100 {
    
    let imageView01 = UIImageView(frame: CGRect(x: 100, y: 100, width: 160, height: 160))
    imageView01.image = image
    view.addSubview(imageView01)
}
```

![](http://upload-images.jianshu.io/upload_images/2069062-74dc9e297e8e113e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

#### 自定义方法创建图像

```swift
for _ in 0..<100 {
    
    let rect02 = CGRect(x: 100, y: 300, width: 160, height: 160)
    let imageView02 = UIImageView(frame: rect02)
    imageView02.image = avatarImage(image: image!, size: rect02.size, backColor: view.backgroundColor)
    view.addSubview(imageView02)
}
```

![](http://upload-images.jianshu.io/upload_images/2069062-9a8f4356c17883a8.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

> 由此可见，新方法对CPU消耗明显减少，内存较以前稍微上涨，CPU消耗减少，则性能有所提升。（因为每次消耗不是一个定数，我这里也是测了很多次取的大概的平均值。）

**简书地址 : [Swift-图像的性能优化](http://www.jianshu.com/p/d49be5f77b7f)**