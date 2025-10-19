+++
date = '2025-10-19T13:14:45+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment0'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业","Games101"]
+++
# Assignment0
前边一大半主要是安装虚拟机保证运行一致，这里就跳过了，到实际的问题：点旋转和平移
![在这里插入图片描述](26aaf651fbad47eca926587f0581a4cc.png)
##  使用Eigen表示向量
点$P=(2,1)$ 表示为 `    Eigen::Vector3f point(2, 1, 1);`，最后一位是用于齐次坐标，为1时表示是一个点
##  点旋转矩阵
	**二维点旋转矩阵**比较简单，推导主要是通过设A、B、C、D四个变量，找两个特殊点求解
![在这里插入图片描述](2703bfe2cee44ac4b97c54c3d8b35851.png)
**三维点旋转矩阵**可分解为分别绕三个轴旋转
![在这里插入图片描述](111ec31010d54d3ba088c3f9c8aa8ed2.png)
注意：上述提到的公式都是按照逆时针旋转的矩阵，顺时针相当于逆时针旋转$-θ$，本题只涉及二维点旋转
##  平移
平移可以简单通过加法实现，但是如果想统一格式，用一个矩阵表示点的所有变换操作，就需要用到齐次坐标，利用齐次坐标表示转换矩阵，可以把旋转缩放平移同时塞到一个矩阵中。下图为只进行平移操作的齐次转换矩阵
![在这里插入图片描述](746515aa8ddb49d59c25a6037137c2d4.png)
旋转矩阵的齐次坐标表达为：
![在这里插入图片描述](d4535e0adecb44019c184f1ad6eee1c7.png)
平移 (1,2)，只需要把tx换为1，ty换为2，得到平移矩阵的齐次坐标表达为：
![在这里插入图片描述](a87325807ada4602b8584fd64d17017e.png)
##  旋转和平移组合
得到最终旋转+平移的矩阵为：
![在这里插入图片描述](4fa2012abd2d4722b700bed15d4b3ffa.png)
##  代码实现
`std::sin`和`std::cos`的参数为弧度制，用角度/180*Π得到。例如cos45°可以表达为`std::cos(45.0/180.0*acos(-1))`,其中acos(-1)就等于Π

```cpp
    // 作业0实现
    std::cout << "作业0实现" << std::endl;
    Eigen::Vector3f point(2, 1, 1);
    Eigen::Matrix3f rotate;
    std::cout << "转换矩阵" << std::endl;
    rotate <<  std::cos(45.0/180.0*acos(-1)),-std::sin(45.0/180.0*acos(-1)),1,std::sin(45.0/180.0* acos(-1)),std::cos(45.0/180.0*acos(-1)),2,0,0,1;
    std::cout << rotate << std::endl;
    Eigen::Vector3f res = rotate*point;
    std::cout << "结果" << std::endl;
    std::cout << res << std::endl;

```

