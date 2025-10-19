+++
date = '2025-10-19T13:23:42+08:00'
draft = false
title = 'GAMES101 现代计算机图形学入门 Assignment4'
categories = ["Course/Games101","Assignment"]
tags = ["课程作业","Games101"]
+++
# 作业介绍
本期作业将在新的代码上完成，就是绘制四个控制点表示的贝塞尔曲线，本次作业的原理很简单，另外我目前并不想把时间花费到写出实现代码上，所以本次代码来自网络，会标明出处
![请添加图片描述](https://i-blog.csdnimg.cn/direct/8a2feb71ac974759bebe37b6dba03b4c.png)
# cv::Point2f recursive_bezier(const std::vector<cv::Point2f> &control_points, float t) 
> 参考https://blog.csdn.net/ycrsw/article/details/124117190?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522409267016115dce86afca8873f30f1ba%2522%252C%2522scm%2522%253A%252220140713.130102334..%2522%257D&request_id=409267016115dce86afca8873f30f1ba&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~all~top_positive~default-1-124117190-null-null.142^v102^pc_search_result_base4&utm_term=games101%E4%BD%9C%E4%B8%9A4&spm=1018.2226.3001.4187

该方法用于返回确定t时，需要绘制的点的坐标

```cpp
bool recursive_bezier(const std::vector<cv::Point2f> &control_points, std::vector<cv::Point2f> &points1, std::vector<cv::Point2f> &points2, float t, cv::Mat &window){
    int size;
    size = points1.size();

    if(size == 1){
        window.at<cv::Vec3b>(points1[0].y, points1[0].x)[1] = 255;//设置该点的绿通道为255
        points2 = control_points;
        points1.clear();//结束计算后记得初始化容器
        return true;
    }
    for(int i = 0; i < size - 1; i++)
        points2.push_back((1 - t) * points1[i] + t * points1[i + 1]);
    points1.clear();
    return false;
}
```
# void bezier(const std::vector<cv::Point2f> &control_points, cv::Mat &window)
当t不断变化下，点也不断变化，从而绘制出曲线

```cpp
void bezier(const std::vector<cv::Point2f> &control_points, cv::Mat &window)
{
    // TODO: Iterate through all t = 0 to t = 1 with small steps, and call de Casteljau's 
    // recursive Bezier algorithm.
    int size = control_points.size();
    std::vector<cv::Point2f> points1 = control_points, points2;
    bool flag = true, bflag;
    for (double t = 0.0; t <= 1.0; t += 0.001)
    {
        bflag = false;
        while(!bflag){
            if(flag)
                bflag = recursive_bezier(control_points, points1, points2, t, window);
            else
                bflag = recursive_bezier(control_points, points2, points1, t, window);
            flag = !flag;
        }
    }
}
```
本次作业主要懂贝塞尔曲线的原理，以及递归代码如何写即可