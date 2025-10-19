+++
date = '2025-10-19T13:21:54+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment1'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业","Games101"]
+++
# 作业介绍
给出三个点的空间坐标，通过MVP矩阵将点投影到平面上，并绘制出三角形
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/4b699439c1a649679ce5aa97175af5ce.png)
# MVP变换
**Model Transformation（模型变换）**：将物体从局部坐标系（Local Space）转换到世界坐标系（World Space），通过以下操作实现：
* 平移（Translate）‌：调整物体在世界空间中的位置；
* 旋转（Rotate）‌：改变物体的朝向；
* 缩放（Scale）‌：控制物体的大小‌

**View Transformation（视图变换）**：
将摄像机移动原点‌；形成以摄像机为中心的视角
‌调整摄像机朝向‌：默认摄像机看向-Z轴方向，Y轴为垂直向上方向；
‌同步变换物体‌：保持物体与摄像机的相对位置关系‌

**Projection Transformation（投影变换）**：
![在这里插入图片描述](https://i-blog.csdnimg.cn/direct/594b42fc6200482991a2c402f81c52d1.png)

将观察空间中的三维物体投影到二维裁剪空间（Clip Space），分为两种类型：

‌正交投影（Orthographic Projection）‌
* 保持物体平行性，无近大远小效果。‌

透视投影（Perspective Projection）‌
* 模拟人眼视觉效果，产生近大远小的深度感。
# 作业代码逻辑解析
main函数分析

```bash
int main(int argc, const char** argv)
{
	// 旋转角度
    float angle = 0;
    bool command_line = false;
    std::string filename = "output.png";
    if (argc >= 3) {
        command_line = true;
        angle = std::stof(argv[2]); // -r by default
        if (argc == 4) {
            filename = std::string(argv[3]);
        }
        else
            return 0;
    }
    rst::rasterizer r(700, 700);
	// 摄像机位置
    Eigen::Vector3f eye_pos = {0, 0, 5};
	// 三角形的三个顶点
    std::vector<Eigen::Vector3f> pos{{2, 0, -2}, {0, 2, -2}, {-2, 0, -2}};
	// 顶点顺序
    std::vector<Eigen::Vector3i> ind{{0, 1, 2}};
	// 顶点坐标和顺序加载到光栅器
    auto pos_id = r.load_positions(pos);
    auto ind_id = r.load_indices(ind);
    int key = 0;
    int frame_count = 0;
    if (command_line) {
        r.clear(rst::Buffers::Color | rst::Buffers::Depth);
        // 设置MVP三个矩阵
        r.set_model(get_model_matrix(angle));
        r.set_view(get_view_matrix(eye_pos));
        r.set_projection(get_projection_matrix(45, 1, 0.1, 50));
		// 画出图形
        r.draw(pos_id, ind_id, rst::Primitive::Triangle);
        cv::Mat image(700, 700, CV_32FC3, r.frame_buffer().data());
        image.convertTo(image, CV_8UC3, 1.0f);
        cv::imwrite(filename, image);
        return 0;
    }
    while (key != 27) {
        r.clear(rst::Buffers::Color | rst::Buffers::Depth);
        r.set_model(get_model_matrix(angle));
        r.set_view(get_view_matrix(eye_pos));
        r.set_projection(get_projection_matrix(45, 1, 0.1, 50));
        r.draw(pos_id, ind_id, rst::Primitive::Triangle);
        cv::Mat image(700, 700, CV_32FC3, r.frame_buffer().data());
        image.convertTo(image, CV_8UC3, 1.0f);
        cv::imshow("image", image);
        key = cv::waitKey(10);
        std::cout << "frame count: " << frame_count++ << '\n';
        if (key == 'a') {
            angle += 10;
        }
        else if (key == 'd') {
            angle -= 10;
        }
    }
    return 0;
}
```
这次作业主要就是实现MVP矩阵，一部分代码就是把MVP矩阵装进光栅化器中。所以别的代码已经没必要看了，在下次作业中再细看
# 模型变换：get_model_matrix(float rotation_angle)  
实现model变换，可以进行缩放、平移、旋转，作业这里只需要进行绕z轴的旋转，在上次作业中，上一篇博客已经提到了如何进行三位物体的旋转，绕各个轴都有对应的变换矩阵，直接左乘到坐标向量即可。

```cpp
Eigen::Matrix4f get_model_matrix(float rotation_angle)
{
    Eigen::Matrix4f model = Eigen::Matrix4f::Identity();
    Eigen::Matrix4f rotationMatrix;
    rotationMatrix << cos(rotation_angle/180* MY_PI),-sin(rotation_angle/180* MY_PI),0,0, sin(rotation_angle/180*MY_PI),cos(rotation_angle/180* MY_PI),0,0,0,0,1,0,0,0,0,1;
    return rotationMatrix;
}
```
# 视图变换：get_view_matrix(Eigen::Vector3f eye_pos)
本次作业并没有让完成这部分，已经被写好了，这里写分析一下代码，视图变换主要作用就是如何把摄像机放在世界远点来进行观察，main函数中已经定义了`Eigen::Vector3f eye_pos = {0, 0, 5};`

```cpp
Eigen::Matrix4f get_view_matrix(Eigen::Vector3f eye_pos)
{
    Eigen::Matrix4f view = Eigen::Matrix4f::Identity();
    Eigen::Matrix4f translate;
    translate << 1, 0, 0, -eye_pos[0], 0, 1, 0, -eye_pos[1], 0, 0, 1,
        -eye_pos[2], 0, 0, 0, 1;
    view = translate * view;
    return view;
}
```
其中可以看出视图变换的矩阵为![请添加图片描述](https://i-blog.csdnimg.cn/direct/0c04d6d434ba4bcdad915b664821af7f.png)，说明只进行了平移操作，摄像机的向上方向和看的方向都为默认。为其他所以物体的坐标都左乘这个矩阵，就实现了所有物体以摄像机为原点的位置坐标

# 投影变换：get_projection_matrix(float eye_fov, float aspect_ratio, float，zNear, float zFar)
>本节图片来自https://zhuanlan.zhihu.com/p/620496517

在给定的参数描述下，就可以确定整个需要投影的空间位置，如下图所示，目标就是把这个立方体区域转换到NDC坐标
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8e4ae887f8d64845921ac71ce1216857.png)
第一步的目标是将该区域变为长方体区域，在进行转换时，离得远的物体就会相应的变小
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8b27fc48be304cf68e0a1f2aeba52233.png)

从+x向-x方向看结构如下图，压缩比例应该为n/z,所以 y = ny/z,x同理
![请添加图片描述](https://i-blog.csdnimg.cn/direct/125a1c9d3bde48beada854f2e4f4394a.png)
设计一个变换矩阵
![请添加图片描述](https://i-blog.csdnimg.cn/direct/011f70f5f7e94e32a549f5ba959b795a.png)
左乘后同时除以z，根据齐次坐标的性质，仍表示同一个坐标，这样每个坐标的x，y都处理好了，就剩下z未处理，其中包含a,b,c,d4个未知数
![请添加图片描述](https://i-blog.csdnimg.cn/direct/4787a7dfe146436d903a74eca24541d9.png)

z坐标获得与上次作业旋转公式推导的方法相似，取几个在变化过程中不会变z的坐标来求解
近平面上（$x^1,y^1,n,1$）与中心点（$0,0,n,1$），远平面（$x^2,y^2,f,1$）和中心点$0,0,f,1$），通过这些点，以及全部近面和远面中心点z不会变这些信息，可以算出a,b,c,d如何取值，最终得到的变换矩阵为
![请添加图片描述](https://i-blog.csdnimg.cn/direct/9b49ae0f8b2146c8bcb45358c839dbe7.png)
但是并没有结束，此时以及得到如下图所示的情况，下一步还需要把空间移动到NDC，就是将长方体变为坐标值在 $[-1,1]^3$
 的立方体。（从这里开始，其实就是正交投影的过程）
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8b27fc48be304cf68e0a1f2aeba52233.png)
以上图坐标为例，平移的方向和距离用t表示很好理解，就是把整个空间的中心挪到坐标原点
$$
t = \left( -\frac{l + r}{2},\ -\frac{b + t}{2},\ -\frac{n + f}{2} \right)
$$
下一步就是把所有坐标都进行单位化，就是把长方体的变长都变成1，对坐标进行统一缩小，缩小矩阵如下
![请添加图片描述](https://i-blog.csdnimg.cn/direct/6f6fc36c443540b99e49607bf06005f6.png)
结合上边的平移后得到正交投影的变化矩阵
![请添加图片描述](https://i-blog.csdnimg.cn/direct/738469fa56d040888acc4cb38423c5bc.png)
结合透视和正交的矩阵就可以得到最终的投影矩阵
# 代码实现
> 代码来自https://blog.csdn.net/qq_41265365/article/details/124229095，懒得算了，就是把三个矩阵合并成了一个写的
```cpp
Eigen::Matrix4f get_projection_matrix(float eye_fov, float aspect_ratio,
                                      float zNear, float zFar)
{
    Eigen::Matrix4f Mpersp;
    float fovY = eye_fov*MY_PI/180.0;
    float cota = 1.f/tanf(fovY/2);
    float zD = zNear-zFar;
    Mpersp << -cota/aspect_ratio, 0, 0, 0,
            0, -cota, 0, 0,
            0, 0, (zNear+zFar)/zD, -2*zNear*zFar/zD,
            0, 0, 1, 0;
    return Mpersp;
}
```
