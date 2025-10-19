+++
date = '2025-10-19T00:47:26+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Transformation & Rasterization'
categories = ["Course/Games101"]
tags = ["笔记"]
+++

@[TOC](目录)
>[GitHub主页](https://github.com/sdpyy1)：https://github.com/sdpyy
[games101项目作业代码](https://github.com/sdpyy1/CppLearn/tree/main/games101)：https://github.com/sdpyy1/CppLearn/tree/main/games101


# 线性代数复习

## 向量

首先介绍一下向量，有长度有方向，起始位置不固定
![在这里插入图片描述](0cf789e58553444d93cff71c08defe69.png)
向量归一化，就是获得向量方向上的单位向量，后续课程各种操作都是在单位向量上进行
![在这里插入图片描述](3a1dbb53ecf24ac5a3a6924380cd0fce.png)
向量加法
![在这里插入图片描述](16979f8f8e314502a50499e210cb1241.png)
## 点乘和叉乘
向量点乘，在后续课程中用来计算cosθ，如果两个单位向量点乘结果就是cosθ
![在这里插入图片描述](ba36e5f8d6774f52815e0b203a9eb3e2.png)
在坐标系中的使用，就是对应坐标相乘再相加
![在这里插入图片描述](a2583128ce874f96b266b4b1920dbb3d.png)
点乘可以用来投影
![在这里插入图片描述](3eb2f75a0424479d842655c9586ae10b.png)
向量叉乘
![在这里插入图片描述](8de7a030c8074905a17feb911c59825d.png)
在坐标系中的使用，有公式
![在这里插入图片描述](3b45ea1aaf4f48c6b375f8a867929baf.png)
在图形中的使用是可以判断一个点是否在三角形内部，在光栅化时用来判断一个像素是否需要被渲染
![在这里插入图片描述](416df626f00642e2917dc882af81999f.png)
## 矩阵
矩阵就不说了，比较容易
## Transformation（变换）
### Model Transformation
模型变换可以做缩放、旋转、平移
通过矩阵计算实现的缩放
![在这里插入图片描述](b6b20ba2d3684b0e8f80e27ea37c2de9.png)
旋转
![在这里插入图片描述](3d23bd7f8fdc4adfa5ef11d68f2d98fd.png)







# 笔记保存
`games101课程光栅化之前的笔记，发现还是直接写博客方便，后续用CSDN完成笔记，前边部分先贴在这里，以后再补充` 
这是之前遗留的笔记，放在这里保存
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8750d51737f0475babe2875df6ffcd6d.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/84752f1b120f4e058fda182c7b03b50f.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/31c09e5916fa49e98190eb1d3f547191.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/74710fbd6e7146d298a020c0eba472e1.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/096ef71415ff47c3b1ddcc6f0220ec08.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/d343e7ad83204472a6e61f581d4e1c0f.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/20402b23e5de445e82fadb8c816c75e9.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/9a4c3613a85a4ba5bca6d1dd701fea48.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/2dd52198035446238adaa55e904b2353.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/cf449ec17b0845d8a68354f761c39d3d.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8c9f224ae52a4119a0b391d6e5e24787.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/0d0154d6b0be4c9bb4bfaf91bc6d74ab.jpeg)
![请添加图片描述](https://i-blog.csdnimg.cn/direct/1ab84e1c2ff0403b855e32c56748baea.jpeg)
