+++
date = '2025-10-19T13:22:24+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment2'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业"]
+++
# 作业介绍
上节课通过MVP+视口变换把三角形三个顶点从空间坐标转移到了屏幕上的坐标，并绘制三角形，这节课将通过光栅化技术，构造实心的三角形
![请添加图片描述](484176b17be14a7abb3a3253a91812ef.png)
# 视口变换？
说是上节课实现了这个，但是任务中并没有，源码中已经实现了视口变换，这里就看一下它如何实现的

```cpp
        //Viewport transformation
        for (auto & vert : v)
        {
            vert.x() = 0.5*width*(vert.x()+1.0);
            vert.y() = 0.5*height*(vert.y()+1.0);
            vert.z() = vert.z() * f1 + f2;
        }
```
以x举例，NDC坐标下x的范围为[-1,1]，首先+1，将范围固定到[0,2],下一步乘0.5乘width,就固定到了[0,width]的范围，也就是屏幕的范围。y坐标同理（y坐标可能需要反转，因为屏幕坐标y可能是向下走的）。
下面看对z坐标的变化。这里我其实不是理解在干什么，下边是deepseek的解释：
视口变换的 ‌z坐标处理‌ 通常是将归一化设备坐标（NDC）的z值映射到深度缓冲的合法范围（如[0,1]）。然而，在你的代码中，f1和f2的设置（f1 = 24.95, f2 = 25.05）表明z坐标被映射到了‌非标准的线性深度范围‌，而非常规的[0,1]
```cpp
float f1 = (50 - 0.1) / 2.0;
float f2 = (50 + 0.1) / 2.0;
vert.z() = vert.z() * f1 + f2;
```
# 源码分析
这里只需要看一下`rst::rasterizer::draw(pos_buf_id pos_buffer, ind_buf_id ind_buffer, col_buf_id col_buffer, Primitive type)`这个函数干了什么

```cpp
void rst::rasterizer::draw(pos_buf_id pos_buffer, ind_buf_id ind_buffer, col_buf_id col_buffer, Primitive type)
{
    auto& buf = pos_buf[pos_buffer.pos_id];
    auto& ind = ind_buf[ind_buffer.ind_id];
    auto& col = col_buf[col_buffer.col_id];

    float f1 = (50 - 0.1) / 2.0;
    float f2 = (50 + 0.1) / 2.0;
	// MVP矩阵
    Eigen::Matrix4f mvp = projection * view * model;
    // 对每个顶点进行MVP+视口变换+设置颜色
    for (auto& i : ind)
    {
    	// 定义一个三角形，设置它的属性，此时设置的已经是在屏幕上的三角形
        Triangle t;
        Eigen::Vector4f v[] = {
                mvp * to_vec4(buf[i[0]], 1.0f),
                mvp * to_vec4(buf[i[1]], 1.0f),
                mvp * to_vec4(buf[i[2]], 1.0f)
        };
        //Homogeneous division
        for (auto& vec : v) {
            vec /= vec.w();
        }
        //Viewport transformation
        for (auto & vert : v)
        {
            vert.x() = 0.5*width*(vert.x()+1.0);
            vert.y() = 0.5*height*(vert.y()+1.0);
            vert.z() = vert.z() * f1 + f2;
        }

        for (int i = 0; i < 3; ++i)
        {
            t.setVertex(i, v[i].head<3>());
            t.setVertex(i, v[i].head<3>());
            t.setVertex(i, v[i].head<3>());
        }

        auto col_x = col[i[0]];
        auto col_y = col[i[1]];
        auto col_z = col[i[2]];

        t.setColor(0, col_x[0], col_x[1], col_x[2]);
        t.setColor(1, col_y[0], col_y[1], col_y[2]);
        t.setColor(2, col_z[0], col_z[1], col_z[2]);
		// 这里就是要实现的函数，传入的就是三角形
        rasterize_triangle(t);
    }
}
```
# 光栅化
整体流程就是计算这个三角形需要涉及到哪些像素点，并对这些像素点设置属性，最后所有需要处理的像素点信息都存到了一个buffer中，调Opencv相关功能把它画出来，这里需要干的事就是给每个像素需要的东西计算出来
## bounding box
画一个三角形没必要遍历所有像素点来找属于该三角形的像素点，只需要线框选一个范围，在这个范围内进行遍历即可，最简单的办法就是找三个坐标最左最右最上最下四个标记点，框选即可，具体做法如下（取值时还会向外扩展一个像素，这是为了‌确保覆盖所有可能被三角形覆盖的像素，因为浮点数本来就是不准确的）

```cpp
    int minX = std::floor((std::min({t.v[0].x(),t.v[1].x(),t.v[2].x()}))-0.5);
    int maxX = std::ceil(std::max({t.v[0].x(),t.v[1].x(),t.v[2].x()})+0.5);
    int minY = std::floor(std::min({t.v[0].y(),t.v[1].y(),t.v[2].y()})-0.5);
    int maxY = std::ceil(std::max({t.v[0].y(),t.v[1].y(),t.v[2].y()})+0.5);
```
## 如何判定像素点在三角形内部
通过上一步已经确定了三角形的大概范围，下一步就是需要判断具体哪些像素确实需要处理，实现思路主要是通过叉乘计算，连接三角形顶点和像素点形成三个向量，用这三个向量分别叉乘三角形的三条边，如果得到的向量方向相同，说明像素点在三角形内部。具体实现如下，写的比较繁琐，但是好理解

```cpp
static bool insideTriangle(int x, int y, const Vector3f* _v)
{   
    // TODO : Implement this function to check if the point (x, y) is inside the triangle represented by _v[0], _v[1], _v[2]
    // 设置三条边对应的向量
    Eigen::Vector3i triangleEdgeVector1(_v[1].x()-_v[0].x(),_v[1].y()-_v[0].y(),0);
    Eigen::Vector3i triangleEdgeVector2(_v[2].x()-_v[1].x(),_v[2].y()-_v[1].y(),0);
    Eigen::Vector3i triangleEdgeVector3(_v[0].x()-_v[2].x(),_v[0].y()-_v[2].y(),0);

    Eigen::Vector3i p1(x-_v[0].x(),y-_v[0].y(),0);
    Eigen::Vector3i p2(x-_v[1].x(),y-_v[1].y(),0);
    Eigen::Vector3i p3(x-_v[2].x(),y-_v[2].y(),0);

    bool flag1 = triangleEdgeVector1.cross(p1).z() > 0;
    bool flag2 = triangleEdgeVector2.cross(p2).z() > 0;
    bool flag3 = triangleEdgeVector3.cross(p3).z() >0;
    if(flag1 == flag2 && flag2 == flag3) return true;
    return false;
}
```
# 像素点处理
经过上一步，已经确定了哪些像素点在三角形内部，下来就是对这些像素点进行处理，首先确定需要处理哪些东西
* z坐标（因为从摄像机看，进处的物体会挡住远处的物体，所以只需要渲染离屏幕更近的颜色，实现就是用z-buffer技术，其实本质就是缓存每个像素点当前最近的距离，如果遍历的像素点比buffer还近就替换他）
* 颜色
## 颜色处理
如果你看到下节课，颜色是通过三个顶点颜色进行插值获得的，这节作业还没用到，看源码，每个三角形的三个顶点都被设置成了同一个颜色，所以这里只需要把颜色设置为顶点颜色即可

## Z坐标处理
按照学习的内容，z坐标应该为三个顶点z坐标插值得到，但是这里并不是，并且算法也是直接给出，并不是课程内容。z坐标计算如下，`computeBarycentric2D`用来获取当前像素点的重心坐标，下节课会讲到的。至于z坐标的处理方式，用到一个透视校正
为什么需要透视校正而不是直接插值，我目前还不懂，问的ai？‌
在透视投影中，物体在近大远小的效果下，其深度（z 值）的分布是 ‌非线性的‌。若直接在屏幕空间线性插值深度，会导致以下问题：
* 远处物体的深度插值过于密集，近处过于稀疏。
* 深度测试（Z-test）不准确，产生渲染错误（如 Z-fighting）。

所以这里就直接调用了，不研究了
```cpp
auto[alpha, beta, gamma] = computeBarycentric2D(i, j, t.v);
float w_reciprocal = 1.0/(alpha / v[0].w() + beta / v[1].w() + gamma / v[2].w());
float z_interpolated = alpha * v[0].z() / v[0].w() + beta * v[1].z() / v[1].w() + gamma * v[2].z() / v[2].w();
z_interpolated *= w_reciprocal;
```
# 完整代码
⚠️：z-buffer缓存记得处理
```cpp
void rst::rasterizer::rasterize_triangle(const Triangle& t) {
    // 三个顶点的齐次坐标
    auto v = t.toVector4();
    // iterate through the pixel and find if the current pixel is inside the triangle   取边界时要向外扩展一个像素
    int minX = std::floor((std::min({t.v[0].x(),t.v[1].x(),t.v[2].x()}))-0.5);
    int maxX = std::ceil(std::max({t.v[0].x(),t.v[1].x(),t.v[2].x()})+0.5);
    int minY = std::floor(std::min({t.v[0].y(),t.v[1].y(),t.v[2].y()})-0.5);
    int maxY = std::ceil(std::max({t.v[0].y(),t.v[1].y(),t.v[2].y()})+0.5);
    for(int i = minX; i<=maxX;i++){
        for(int j = minY;j<=maxY;j++){
            // 如果划分到三角形内
            if(insideTriangle(i,j,t.v)){
                // If so, use the following code to get the interpolated z value.
                auto[alpha, beta, gamma] = computeBarycentric2D(i, j, t.v);
                float w_reciprocal = 1.0/(alpha / v[0].w() + beta / v[1].w() + gamma / v[2].w());
                float z_interpolated = alpha * v[0].z() / v[0].w() + beta * v[1].z() / v[1].w() + gamma * v[2].z() / v[2].w();
                z_interpolated *= w_reciprocal;
                if(z_interpolated < depth_buf[get_index(i,j)]){
                    // TODO : set the current pixel (use the set_pixel function) to the color of the triangle (use getColor function) if it should be painted.
                    set_pixel(Vector3f(i,j,z_interpolated),t.getColor());
                    depth_buf[get_index(i,j)] = z_interpolated;
                }
            }
        }
    }
}
```

