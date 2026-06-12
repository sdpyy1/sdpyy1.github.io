+++date = '2025-10-19T13:37:45+08:00'
draft = false
title = 'TinyRender开发记录 1-4'
categories = ["Projects/CPU渲染器"]
tags = ["渲染器开发","TinyRender"]
image = '015e0f415d1c493db111695862b55bfe.png'
+++
# 项目介绍
> Tiny Renderer or how OpenGL works: software rendering in 500 lines of code
> 项目地址：https://github.com/ssloy/tinyrenderer
> In this series of articles, I want to show how OpenGL works by writing its clone (a much simplified one). Surprisingly enough, I often meet people who cannot overcome the initial hurdle of learning OpenGL / DirectX. Thus, I have prepared a short series of lectures, after which my students show quite good renderers.
So, the task is formulated as follows: using no third-party libraries (especially graphic ones), get something like this picture:

所以学习最终目标是不使用第三方代码，得到下面这种图，建议学完games101后来复习，不过过程很详细，作为入门也是不错的
![请添加图片描述](015e0f415d1c493db111695862b55bfe.png)
# 环境搭建
虽然项目旨在不使用第三方库，但提供了图片读取、保存、设置像素点颜色的代码
tagimage.h

```cpp
#pragma once
#include <cstdint>
#include <fstream>
#include <vector>

#pragma pack(push,1)
struct TGAHeader {
    std::uint8_t  idlength{};
    std::uint8_t  colormaptype{};
    std::uint8_t  datatypecode{};
    std::uint16_t colormaporigin{};
    std::uint16_t colormaplength{};
    std::uint8_t  colormapdepth{};
    std::uint16_t x_origin{};
    std::uint16_t y_origin{};
    std::uint16_t width{};
    std::uint16_t height{};
    std::uint8_t  bitsperpixel{};
    std::uint8_t  imagedescriptor{};
};
#pragma pack(pop)

struct TGAColor {
    std::uint8_t bgra[4] = {0,0,0,0};
    std::uint8_t bytespp = {0};

    TGAColor() = default;
    TGAColor(const std::uint8_t R, const std::uint8_t G, const std::uint8_t B, const std::uint8_t A=255) : bgra{B,G,R,A}, bytespp(4) { }
    TGAColor(const std::uint8_t *p, const std::uint8_t bpp) : bytespp(bpp) {
        for (int i=bpp; i--; bgra[i] = p[i]);
    }
    std::uint8_t& operator[](const int i) { return bgra[i]; }
};

struct TGAImage {
    enum Format { GRAYSCALE=1, RGB=3, RGBA=4 };

    TGAImage() = default;
    TGAImage(const int w, const int h, const int bpp);
    bool  read_tga_file(const std::string filename);
    bool write_tga_file(const std::string filename, const bool vflip=true, const bool rle=true) const;
    void flip_horizontally();
    void flip_vertically();
    TGAColor get(const int x, const int y) const;
    void set(const int x, const int y, const TGAColor &c);
    int width()  const;
    int height() const;
private:
    bool   load_rle_data(std::ifstream &in);
    bool unload_rle_data(std::ofstream &out) const;

    int w   = 0;
    int h   = 0;
    int bpp = 0;
    std::vector<std::uint8_t> data = {};
};
```
tgaimage.cpp

```cpp
#include <iostream>
#include <cstring>
#include "tgaimage.h"

TGAImage::TGAImage(const int w, const int h, const int bpp) : w(w), h(h), bpp(bpp), data(w*h*bpp, 0) {}

bool TGAImage::read_tga_file(const std::string filename) {
    std::ifstream in;
    in.open (filename, std::ios::binary);
    if (!in.is_open()) {
        std::cerr << "can't open file " << filename << "\n";
        in.close();
        return false;
    }
    TGAHeader header;
    in.read(reinterpret_cast<char *>(&header), sizeof(header));
    if (!in.good()) {
        in.close();
        std::cerr << "an error occured while reading the header\n";
        return false;
    }
    w   = header.width;
    h   = header.height;
    bpp = header.bitsperpixel>>3;
    if (w<=0 || h<=0 || (bpp!=GRAYSCALE && bpp!=RGB && bpp!=RGBA)) {
        in.close();
        std::cerr << "bad bpp (or width/height) value\n";
        return false;
    }
    size_t nbytes = bpp*w*h;
    data = std::vector<std::uint8_t>(nbytes, 0);
    if (3==header.datatypecode || 2==header.datatypecode) {
        in.read(reinterpret_cast<char *>(data.data()), nbytes);
        if (!in.good()) {
            in.close();
            std::cerr << "an error occured while reading the data\n";
            return false;
        }
    } else if (10==header.datatypecode||11==header.datatypecode) {
        if (!load_rle_data(in)) {
            in.close();
            std::cerr << "an error occured while reading the data\n";
            return false;
        }
    } else {
        in.close();
        std::cerr << "unknown file format " << (int)header.datatypecode << "\n";
        return false;
    }
    if (!(header.imagedescriptor & 0x20))
        flip_vertically();
    if (header.imagedescriptor & 0x10)
        flip_horizontally();
    std::cerr << w << "x" << h << "/" << bpp*8 << "\n";
    in.close();
    return true;
}

bool TGAImage::load_rle_data(std::ifstream &in) {
    size_t pixelcount = w*h;
    size_t currentpixel = 0;
    size_t currentbyte  = 0;
    TGAColor colorbuffer;
    do {
        std::uint8_t chunkheader = 0;
        chunkheader = in.get();
        if (!in.good()) {
            std::cerr << "an error occured while reading the data\n";
            return false;
        }
        if (chunkheader<128) {
            chunkheader++;
            for (int i=0; i<chunkheader; i++) {
                in.read(reinterpret_cast<char *>(colorbuffer.bgra), bpp);
                if (!in.good()) {
                    std::cerr << "an error occured while reading the header\n";
                    return false;
                }
                for (int t=0; t<bpp; t++)
                    data[currentbyte++] = colorbuffer.bgra[t];
                currentpixel++;
                if (currentpixel>pixelcount) {
                    std::cerr << "Too many pixels read\n";
                    return false;
                }
            }
        } else {
            chunkheader -= 127;
            in.read(reinterpret_cast<char *>(colorbuffer.bgra), bpp);
            if (!in.good()) {
                std::cerr << "an error occured while reading the header\n";
                return false;
            }
            for (int i=0; i<chunkheader; i++) {
                for (int t=0; t<bpp; t++)
                    data[currentbyte++] = colorbuffer.bgra[t];
                currentpixel++;
                if (currentpixel>pixelcount) {
                    std::cerr << "Too many pixels read\n";
                    return false;
                }
            }
        }
    } while (currentpixel < pixelcount);
    return true;
}

bool TGAImage::write_tga_file(const std::string filename, const bool vflip, const bool rle) const {
    constexpr std::uint8_t developer_area_ref[4] = {0, 0, 0, 0};
    constexpr std::uint8_t extension_area_ref[4] = {0, 0, 0, 0};
    constexpr std::uint8_t footer[18] = {'T','R','U','E','V','I','S','I','O','N','-','X','F','I','L','E','.','\0'};
    std::ofstream out;
    out.open (filename, std::ios::binary);
    if (!out.is_open()) {
        std::cerr << "can't open file " << filename << "\n";
        out.close();
        return false;
    }
    TGAHeader header;
    header.bitsperpixel = bpp<<3;
    header.width  = w;
    header.height = h;
    header.datatypecode = (bpp==GRAYSCALE?(rle?11:3):(rle?10:2));
    header.imagedescriptor = vflip ? 0x00 : 0x20; // top-left or bottom-left origin
    out.write(reinterpret_cast<const char *>(&header), sizeof(header));
    if (!out.good()) {
        out.close();
        std::cerr << "can't dump the tga file\n";
        return false;
    }
    if (!rle) {
        out.write(reinterpret_cast<const char *>(data.data()), w*h*bpp);
        if (!out.good()) {
            std::cerr << "can't unload raw data\n";
            out.close();
            return false;
        }
    } else if (!unload_rle_data(out)) {
        out.close();
        std::cerr << "can't unload rle data\n";
        return false;
    }
    out.write(reinterpret_cast<const char *>(developer_area_ref), sizeof(developer_area_ref));
    if (!out.good()) {
        std::cerr << "can't dump the tga file\n";
        out.close();
        return false;
    }
    out.write(reinterpret_cast<const char *>(extension_area_ref), sizeof(extension_area_ref));
    if (!out.good()) {
        std::cerr << "can't dump the tga file\n";
        out.close();
        return false;
    }
    out.write(reinterpret_cast<const char *>(footer), sizeof(footer));
    if (!out.good()) {
        std::cerr << "can't dump the tga file\n";
        out.close();
        return false;
    }
    out.close();
    return true;
}

// TODO: it is not necessary to break a raw chunk for two equal pixels (for the matter of the resulting size)
bool TGAImage::unload_rle_data(std::ofstream &out) const {
    const std::uint8_t max_chunk_length = 128;
    size_t npixels = w*h;
    size_t curpix = 0;
    while (curpix<npixels) {
        size_t chunkstart = curpix*bpp;
        size_t curbyte = curpix*bpp;
        std::uint8_t run_length = 1;
        bool raw = true;
        while (curpix+run_length<npixels && run_length<max_chunk_length) {
            bool succ_eq = true;
            for (int t=0; succ_eq && t<bpp; t++)
                succ_eq = (data[curbyte+t]==data[curbyte+t+bpp]);
            curbyte += bpp;
            if (1==run_length)
                raw = !succ_eq;
            if (raw && succ_eq) {
                run_length--;
                break;
            }
            if (!raw && !succ_eq)
                break;
            run_length++;
        }
        curpix += run_length;
        out.put(raw?run_length-1:run_length+127);
        if (!out.good()) {
            std::cerr << "can't dump the tga file\n";
            return false;
        }
        out.write(reinterpret_cast<const char *>(data.data()+chunkstart), (raw?run_length*bpp:bpp));
        if (!out.good()) {
            std::cerr << "can't dump the tga file\n";
            return false;
        }
    }
    return true;
}

TGAColor TGAImage::get(const int x, const int y) const {
    if (!data.size() || x<0 || y<0 || x>=w || y>=h)
        return {};
    return TGAColor(data.data()+(x+y*w)*bpp, bpp);
}

void TGAImage::set(int x, int y, const TGAColor &c) {
    if (!data.size() || x<0 || y<0 || x>=w || y>=h) return;
    memcpy(data.data()+(x+y*w)*bpp, c.bgra, bpp);
}

void TGAImage::flip_horizontally() {
    int half = w>>1;
    for (int i=0; i<half; i++)
        for (int j=0; j<h; j++)
            for (int b=0; b<bpp; b++)
                std::swap(data[(i+j*w)*bpp+b], data[(w-1-i+j*w)*bpp+b]);
}

void TGAImage::flip_vertically() {
    int half = h>>1;
    for (int i=0; i<w; i++)
        for (int j=0; j<half; j++)
            for (int b=0; b<bpp; b++)
                std::swap(data[(i+j*w)*bpp+b], data[(i+(h-1-j)*w)*bpp+b]);
}

int TGAImage::width() const {
    return w;
}

int TGAImage::height() const {
    return h;
}
```
写一个测试来确保环境正常

```cpp
#include "tgaimage.h"
const TGAColor white = TGAColor(255, 255, 255, 255);
const TGAColor red   = TGAColor(255, 0,   0,   255);
int main(int argc, char** argv) {
    TGAImage image(100, 100, TGAImage::RGB);
    image.set(52, 41, red);
    image.flip_vertically(); // 垂直方向翻转图片，反转y坐标，作者解释是希望图片的原点在左下角，但很多库原点都在左上角
    image.write_tga_file("output.tga");
    return 0;
}
```
运行后图片如下
![在这里插入图片描述](688a268895e54c2cba897784c8d8717d.png)
# Lesson 1: Bresenham’s Line Drawing Algorithm（画线算法）
首先进行初始化，在图上标记三个位置

```cpp
#include "tgaimage.h"
constexpr TGAColor white   = {255, 255, 255, 255}; // attention, BGRA order
constexpr TGAColor green   = {  0, 255,   0, 255};
constexpr TGAColor red     = {  255,   0, 0, 255};
constexpr TGAColor blue    = {255, 128,  64, 255};
constexpr TGAColor yellow  = {  0, 200, 255, 255};
int main(int argc, char** argv) {
    constexpr int width  = 64;
    constexpr int height = 64;
    TGAImage framebuffer(width, height, TGAImage::RGB);
    int ax =  7, ay =  3;
    int bx = 12, by = 37;
    int cx = 62, cy = 53;
    framebuffer.set(ax, ay, white);
    framebuffer.set(bx, by, white);
    framebuffer.set(cx, cy, white);
    framebuffer.write_tga_file("framebuffer.tga");
    return 0;
}
```
得到结果如下
![请添加图片描述](6e3c25d11b5d4a0bb5a8bb253aa08129.png)
首先来学习下如何在像素上画一条线
第一次尝试：想象用参数t来表示的一个在$x_a和x_b$之间的点$(x(t),y(t))$
$$
\begin{cases}
x(t) = a_x + t \cdot (b_x - a_x) \\
y(t) = a_y + t \cdot (b_y - a_y)
\end{cases}
$$
如果我们变换一下形式就会发现，这就是插值的公式
$$
\begin{cases}
x(t) = (1-t) \cdot a_x + t \cdot b_x \\
y(t) = (1-t) \cdot a_y + t \cdot b_y
\end{cases}
$$
下面来尝试一下通过控制t来绘制这条直线

```cpp
void drawLine_first(int x1,int y1,int x2,int y2,TGAImage &img,TGAColor color){
    for(float t = 0;t<=1;t+=0.02){
        int x = std::round(x1 + t * (x2-x1)); // round会进行四舍五入
        int y = std::round(y1 + t * (y2-y1));
        img.set(x,y,color);
    }
}
```
![请添加图片描述](83e2a9f608014995bad864ce81613342.png)

考虑左下角的a点和右上角的c点，如果我从a向c绘制一次，再从c向a绘制一次，结果如下
![请添加图片描述](4cd7b745f87a4d40ba33731bcf17bc71.png)


图中能明显看出问题，一是在x上有缝隙，二是不同的绘制方向结果是不同的，
第三另外t步长的设置也不容易控制
接下来看第二种尝试，代码的改变写在了注释中

```cpp
void drawLine_Second(int ax, int ay, int bx, int by, TGAImage &img, TGAColor color){
    for (int x = ax ; x<= bx; x++) { // 不再以t控制，而是以x的进行进行控制，保证了水平方向上不会有空隙
    	// 如果不加强制转换，当分子分母都是整数时，计算结果的小数部分会被截断
        float t = (x-ax)/static_cast<float>(bx-ax); // 变换了形式，表示出当x移动一格时，t是多少，
        int y = std::round( ay + (by-ay)*t );
        img.set(x, y, color);
    }
}
```
这里碰到了Cpp的static_cast<float>，顺便学习一下是什么
隐式转换（Implicit Conversion）：编译器或解释器‌自动完成‌的类型转换，无需程序员显式指定。
显式转换（Explicit Conversion）：程序员‌主动指定‌的类型转换，通常通过语法或函数强制实现。
static_cast是 C++ 中一种显式类型转换操作符，‌用于在编译时进行类型转换，‌适用场景‌：明确的、安全的类型转换（如基本类型转换、向上转换、void* 转换），不用c语言风格的强制转换是为了规避风险。
从下图看到问题2，3已经解决了，原本有的问题1空隙也没有了，但是出现了新的很大的空隙，甚至一条线直接消失了
![请添加图片描述](741bb0725cbb48a1bc6945f21685cd00.png)
线消失比较好解决，原因就是从右上角向左下角画线，if就进不去

```cpp
void drawLine_Second(int ax, int ay, int bx, int by, TGAImage &img, TGAColor color){
    if (ax>bx) { // make it left−to−right
        std::swap(ax, bx);
        std::swap(ay, by);
    }
    for (int x = ax ; x<= bx; x++) { // 不再以t控制，而是以x的进行进行控制，保证了水平方向上不会有空隙
        // 如果不加强制转换，当分子分母都是整数时，计算结果的小数部分会被截断
        float t = (x-ax)/static_cast<float>(bx-ax); // 变换了形式，表示出当x移动一格时，t是多少，
        int y = std::round( ay + (by-ay)*t );
        img.set(x, y, color);
    }
}
```
![请添加图片描述](b301f31203f1422699e3fd87d650b1c1.png)
下面就要解决a->b这么大空隙了，这个问题就是斜率大的线段的采样不足，因为x只走了几步就到了，也就只会画出几个点
接下来进行第三次尝试，解决思路就是如果斜率太大，就从y进行for，而不是x，教程中的解决思路十分巧妙，如果斜率太大，就交换x坐标和y坐标，同时绘制时绘制坐标变成$(y,x)$

```cpp
// 最终版本
void drawLine(int ax, int ay, int bx, int by, TGAImage &framebuffer, TGAColor color) {
    bool steep = std::abs(ax-bx) < std::abs(ay-by);
    if (steep) { // if the drawLine is steep, we transpose the image
        std::swap(ax, ay);
        std::swap(bx, by);
    }
    if (ax>bx) { // make it left−to−right
        std::swap(ax, bx);
        std::swap(ay, by);
    }
    int y = ay;
    int ierror = 0;
    for (int x=ax; x<=bx; x++) {
        if (steep) // if transposed, de−transpose
            framebuffer.set(y, x, color);
        else
            framebuffer.set(x, y, color);
        ierror += 2 * std::abs(by-ay);
        y += (by > ay ? 1 : -1) * (ierror > bx - ax);
        ierror -= 2 * (bx-ax)   * (ierror > bx - ax);
    }
}
```
![请添加图片描述](b3d23e59f61744fcb488d9bef6bdef6b.png)
至此就完成了比较好的效果的直线绘制，第四次尝试是如何优化算法的运行速度，这里就不说了，直接上他最终的优化代码作为后续使用，但是走样（锯齿）问题没有解决，这里不详细说，后边课程肯定会涉及到。

# Lesson 2: Triangle rasterization 三角形光栅化
本节课目的是画一个实心的三角形（上节课只画了边）
首先提供一个画线框三角形的代码
```cpp
constexpr int width  = 128;
constexpr int height = 128;
// 绘制一个三角形
void drawTriangle(int ax, int ay, int bx, int by, int cx, int cy, TGAImage &framebuffer, TGAColor color) {
    drawLine(ax, ay, bx, by, framebuffer, color);
    drawLine(bx, by, cx, cy, framebuffer, color);
    drawLine(cx, cy, ax, ay, framebuffer, color);
}
// 绘制三个三角形进行测试
int main(int argc, char** argv) {
    TGAImage framebuffer(width, height, TGAImage::RGB);
    drawTriangle(  7, 45, 35, 100, 45,  60, framebuffer, red);
    drawTriangle(120, 35, 90,   5, 45, 110, framebuffer, white);
    drawTriangle(115, 83, 80,  90, 85, 120, framebuffer, green);
    framebuffer.write_tga_file("framebuffer.tga");
    return 0;
}
```
![请添加图片描述](e5e498fd5c20484785954f568a17ac56.png)

填充三角形需要做的事情：
 - 它应该简单快捷
 - 它应该是对称的 —— 输出不应该依赖于传递给函数的顶点顺序
 - 如果两个三角形共享两个顶点，由于光栅化舍入误差，它们之间不应该有间隙
## Scanline rendering  线性扫描
这块不是很想实现，因为学过games101后，已经知道更好的方法是什么了😂，这里参考别的博客看看原理是啥吧。
> https://blog.csdn.net/qq_42987967/article/details/124831459

思路就是先对顶点y坐标进行排序，并从中间顶点水平切一刀，这样扫描时比例变化是正常的不会突然反向，交点A沿t0到t2的主斜边移动，B沿t0到t1的侧边移动，移动过程中填充内部的像素
![请添加图片描述](cda17b2f9bfd4d4eb451cf64a7745f1c.png)
```cpp
void triangle(Vec2i t0, Vec2i t1, Vec2i t2, TGAImage &image, TGAColor color) { 
    // sort the vertices, t0, t1, t2 lower−to−upper (bubblesort yay!) 
    if (t0.y>t1.y) std::swap(t0, t1); 
    if (t0.y>t2.y) std::swap(t0, t2); 
    if (t1.y>t2.y) std::swap(t1, t2); 
    int total_height = t2.y-t0.y; 
    for (int y=t0.y; y<=t1.y; y++) { 
        int segment_height = t1.y-t0.y+1; 
        float alpha = (float)(y-t0.y)/total_height; 
        float beta  = (float)(y-t0.y)/segment_height; // be careful with divisions by zero 
        Vec2i A = t0 + (t2-t0)*alpha; 
        Vec2i B = t0 + (t1-t0)*beta; 
        if (A.x>B.x) std::swap(A, B); 
        for (int j=A.x; j<=B.x; j++) { 
            image.set(j, y, color); // attention, due to int casts t0.y+i != A.y 
        } 
    } 
    for (int y=t1.y; y<=t2.y; y++) { 
        int segment_height =  t2.y-t1.y+1; 
        float alpha = (float)(y-t0.y)/total_height; 
        float beta  = (float)(y-t1.y)/segment_height; // be careful with divisions by zero 
        Vec2i A = t0 + (t2-t0)*alpha; 
        Vec2i B = t1 + (t2-t1)*beta; 
        if (A.x>B.x) std::swap(A, B); 
        for (int j=A.x; j<=B.x; j++) { 
            image.set(j, y, color); // attention, due to int casts t0.y+i != A.y 
        } 
    } 
}
```
## Modern rasterization approach 现代栅格化方法
基本思路就是用包围盒围住三角形，减少需要遍历的三角形数量，之后遍历盒子中每个像素，判断是否在三角形内部，伪代码如下

```cpp
triangle(vec2 points[3]) {
    vec2 bbox[2] = find_bounding_box(points);
    for (each pixel in the bounding box) {
        if (inside(points, pixel)) {
            put_pixel(pixel);
        }
    }
}
```
首先是包围盒的建立，其实就找三个顶点的最大值和最小值，就能画出一个围住三角形最小的矩形

```cpp
    int bbminx = std::min(std::min(ax, bx), cx); // bounding box for the triangle
    int bbminy = std::min(std::min(ay, by), cy); // defined by its top left and bottom right corners
    int bbmaxx = std::max(std::max(ax, bx), cx);
    int bbmaxy = std::max(std::max(ay, by), cy);
```
![请添加图片描述](f25073c07e4b4d54b6e139f39cc31818.png)
之后就是剔除不在三角形内部的像素，在games101提供的方法是用像素坐标叉乘三条边顺序组成的向量，如果叉乘结果都在一个方向，那这个像素点就在三角形内部，在这个教程中并不是这样做的，它是利用重心坐标，计算出一个点对于这个三角形的重心坐标$(\alpha,\beta,\gamma)$，只要有一个是负数，就表示不再三角形内，那就用他这种方法吧。重心坐标反映的是划分为三个小三角形的面积比，如果点在三角形外，那面积算出来就成负数了。
首先提供一个算三角形面积的函数

```cpp
double signed_triangle_area(int ax, int ay, int bx, int by, int cx, int cy) {
    return .5*((by-ay)*(bx+ax) + (cy-by)*(cx+bx) + (ay-cy)*(ax+cx));
}
```
下来就可以用面积比来求重心坐标了

```cpp
#pragma omp parallel for
    for (int x=bbminx; x<=bbmaxx; x++) {
        for (int y=bbminy; y<=bbmaxy; y++) {
            double alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
            double beta  = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
            double gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
            if (alpha<0 || beta<0 || gamma<0) continue; // negative barycentric coordinate => the pixel is outside the triangle
            framebuffer.set(x, y, color);
        }
    }
}
```
#pragma omp parallel for是OpenMP中的一个指令，用于并行化for循环。OpenMP是一种并行编程模型，可以在支持OpenMP的编译器上使用
最终的三角形绘制如下

```cpp
// 绘制一个三角形
void drawTriangle(int ax, int ay, int bx, int by, int cx, int cy, TGAImage &framebuffer, TGAColor color) {
    int bbminx = std::min(std::min(ax, bx), cx); // bounding box for the triangle
    int bbminy = std::min(std::min(ay, by), cy); // defined by its top left and bottom right corners
    int bbmaxx = std::max(std::max(ax, bx), cx);
    int bbmaxy = std::max(std::max(ay, by), cy);
    double total_area = signed_triangle_area(ax, ay, bx, by, cx, cy);

#pragma omp parallel for
    for (int x=bbminx; x<=bbmaxx; x++) {
        for (int y=bbminy; y<=bbmaxy; y++) {
            double alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
            double beta  = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
            double gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
            if (alpha<0 || beta<0 || gamma<0) continue; // negative barycentric coordinate => the pixel is outside the triangle
            framebuffer.set(x, y, color);
        }
    }
}
```
![请添加图片描述](e5edfccf00004d379cb153925d59f177.png)
## back-face culling 背面剔除
一般来说法线背对相机或光线方向的平面可认为是没用的，可以不用绘制将其剔除以减少运算量。原理是如果正面的三角形都是顺时针，那背面的都是逆时针，另外一种方法是计算三角形法向量与摄像机的点乘，小于0说明它是背对的。
在第2课中使用的是计算三角形的面积，下面这个代码是带符号的，所以负的面积说明三角形是背对的。

```cpp
double signed_triangle_area(int ax, int ay, int bx, int by, int cx, int cy) {
    return .5*((by-ay)*(bx+ax) + (cy-by)*(cx+bx) + (ay-cy)*(ax+cx));
}
```
在这里引入向量和模型导入的函数
vector.h

生成下图，可以看出来把所有三角形全画出来，脸部轮廓都不见了
![请添加图片描述](c3c69559df694b75a0c800d12967eba4.png)
修改三角形绘制函数，如果计算出来的三角形面积是负数，就直接不绘制了，这里设置小于1，是把面积太小的三角形直接省略了

```cpp
void drawTriangle(int ax, int ay, int bx, int by, int cx, int cy, TGAImage &framebuffer, TGAColor color) {
    int bbminx = std::min(std::min(ax, bx), cx);
    int bbminy = std::min(std::min(ay, by), cy);
    int bbmaxx = std::max(std::max(ax, bx), cx);
    int bbmaxy = std::max(std::max(ay, by), cy);
    double total_area = signed_triangle_area(ax, ay, bx, by, cx, cy);
    if (total_area<1) return;

#pragma omp parallel for
    for (int x=bbminx; x<=bbmaxx; x++) {
        for (int y=bbminy; y<=bbmaxy; y++) {
            double alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
            double beta  = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
            double gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
            if (alpha<0 || beta<0 || gamma<0) continue;
            framebuffer.set(x, y, color);
        }
    }
}
```
修改后明显可以看出脸部轮廓出来了

![请添加图片描述](3b95c96f682b4d93a042efade3acc9cb.png)
使用2k分辨率，效果更好了
![请添加图片描述](363ae3b883b6477d806ea01bfb04d434.png)
# Lesson 3: Hidden faces removal (z buffer)
首先介绍一下代码变动
模型获取使用开源库

```cpp
//
// Created by LEI XU on 4/28/19.
//
//
// This loader is created by Robert Smith.
// https://github.com/Bly7/OBJ-Loader
// Use the MIT license.


#ifndef RASTERIZER_OBJ_LOADER_H
#define RASTERIZER_OBJ_LOADER_H

#pragma once


#include <iostream>
#include <vector>
#include <string>
#include <fstream>
#include <math.h>

// Print progress to console while loading (large models)
#define OBJL_CONSOLE_OUTPUT

// Namespace: OBJL
//
// Description: The namespace that holds eveyrthing that
//	is needed and used for the OBJ Model Loader
namespace objl
{
    // Structure: Vector2
    //
    // Description: A 2D Vector that Holds Positional Data
    struct Vector2
    {
        // Default Constructor
        Vector2()
        {
            X = 0.0f;
            Y = 0.0f;
        }
        // Variable Set Constructor
        Vector2(float X_, float Y_)
        {
            X = X_;
            Y = Y_;
        }
        // Bool Equals Operator Overload
        bool operator==(const Vector2& other) const
        {
            return (this->X == other.X && this->Y == other.Y);
        }
        // Bool Not Equals Operator Overload
        bool operator!=(const Vector2& other) const
        {
            return !(this->X == other.X && this->Y == other.Y);
        }
        // Addition Operator Overload
        Vector2 operator+(const Vector2& right) const
        {
            return Vector2(this->X + right.X, this->Y + right.Y);
        }
        // Subtraction Operator Overload
        Vector2 operator-(const Vector2& right) const
        {
            return Vector2(this->X - right.X, this->Y - right.Y);
        }
        // Float Multiplication Operator Overload
        Vector2 operator*(const float& other) const
        {
            return Vector2(this->X *other, this->Y * other);
        }

        // Positional Variables
        float X;
        float Y;
    };

    // Structure: Vector3
    //
    // Description: A 3D Vector that Holds Positional Data
    struct Vector3
    {
        // Default Constructor
        Vector3()
        {
            X = 0.0f;
            Y = 0.0f;
            Z = 0.0f;
        }
        // Variable Set Constructor
        Vector3(float X_, float Y_, float Z_)
        {
            X = X_;
            Y = Y_;
            Z = Z_;
        }
        // Bool Equals Operator Overload
        bool operator==(const Vector3& other) const
        {
            return (this->X == other.X && this->Y == other.Y && this->Z == other.Z);
        }
        // Bool Not Equals Operator Overload
        bool operator!=(const Vector3& other) const
        {
            return !(this->X == other.X && this->Y == other.Y && this->Z == other.Z);
        }
        // Addition Operator Overload
        Vector3 operator+(const Vector3& right) const
        {
            return Vector3(this->X + right.X, this->Y + right.Y, this->Z + right.Z);
        }
        // Subtraction Operator Overload
        Vector3 operator-(const Vector3& right) const
        {
            return Vector3(this->X - right.X, this->Y - right.Y, this->Z - right.Z);
        }
        // Float Multiplication Operator Overload
        Vector3 operator*(const float& other) const
        {
            return Vector3(this->X * other, this->Y * other, this->Z * other);
        }
        // Float Division Operator Overload
        Vector3 operator/(const float& other) const
        {
            return Vector3(this->X / other, this->Y / other, this->Z / other);
        }

        // Positional Variables
        float X;
        float Y;
        float Z;
    };

    // Structure: Vertex
    //
    // Description: Model Vertex object that holds
    //	a Position, Normal, and Texture Coordinate
    struct Vertex
    {
        // Position Vector
        Vector3 Position;

        // Normal Vector
        Vector3 Normal;

        // Texture Coordinate Vector
        Vector2 TextureCoordinate;
    };

    struct Material
    {
        Material()
        {
            name;
            Ns = 0.0f;
            Ni = 0.0f;
            d = 0.0f;
            illum = 0;
        }

        // Material Name
        std::string name;
        // Ambient Color
        Vector3 Ka;
        // Diffuse Color
        Vector3 Kd;
        // Specular Color
        Vector3 Ks;
        // Specular Exponent
        float Ns;
        // Optical Density
        float Ni;
        // Dissolve
        float d;
        // Illumination
        int illum;
        // Ambient Texture Map
        std::string map_Ka;
        // Diffuse Texture Map
        std::string map_Kd;
        // Specular Texture Map
        std::string map_Ks;
        // Specular Hightlight Map
        std::string map_Ns;
        // Alpha Texture Map
        std::string map_d;
        // Bump Map
        std::string map_bump;
    };

    // Structure: Mesh
    //
    // Description: A Simple Mesh Object that holds
    //	a name, a vertex list, and an index list
    struct Mesh
    {
        // Default Constructor
        Mesh()
        {

        }
        // Variable Set Constructor
        Mesh(std::vector<Vertex>& _Vertices, std::vector<unsigned int>& _Indices)
        {
            Vertices = _Vertices;
            Indices = _Indices;
        }
        // Mesh Name
        std::string MeshName;
        // Vertex List
        std::vector<Vertex> Vertices;
        // Index List
        std::vector<unsigned int> Indices;

        // Material
        Material MeshMaterial;
    };

    // Namespace: Math
    //
    // Description: The namespace that holds all of the math
    //	functions need for OBJL
    namespace math
    {
        // Vector3 Cross Product
        Vector3 CrossV3(const Vector3 a, const Vector3 b)
        {
            return Vector3(a.Y * b.Z - a.Z * b.Y,
                           a.Z * b.X - a.X * b.Z,
                           a.X * b.Y - a.Y * b.X);
        }

        // Vector3 Magnitude Calculation
        float MagnitudeV3(const Vector3 in)
        {
            return (sqrtf(powf(in.X, 2) + powf(in.Y, 2) + powf(in.Z, 2)));
        }

        // Vector3 DotProduct
        float DotV3(const Vector3 a, const Vector3 b)
        {
            return (a.X * b.X) + (a.Y * b.Y) + (a.Z * b.Z);
        }

        // Angle between 2 Vector3 Objects
        float AngleBetweenV3(const Vector3 a, const Vector3 b)
        {
            float angle = DotV3(a, b);
            angle /= (MagnitudeV3(a) * MagnitudeV3(b));
            return angle = acosf(angle);
        }

        // Projection Calculation of a onto b
        Vector3 ProjV3(const Vector3 a, const Vector3 b)
        {
            Vector3 bn = b / MagnitudeV3(b);
            return bn * DotV3(a, bn);
        }
    }

    // Namespace: Algorithm
    //
    // Description: The namespace that holds all of the
    // Algorithms needed for OBJL
    namespace algorithm
    {
        // Vector3 Multiplication Opertor Overload
        Vector3 operator*(const float& left, const Vector3& right)
        {
            return Vector3(right.X * left, right.Y * left, right.Z * left);
        }

        // A test to see if P1 is on the same side as P2 of a line segment ab
        bool SameSide(Vector3 p1, Vector3 p2, Vector3 a, Vector3 b)
        {
            Vector3 cp1 = math::CrossV3(b - a, p1 - a);
            Vector3 cp2 = math::CrossV3(b - a, p2 - a);

            if (math::DotV3(cp1, cp2) >= 0)
                return true;
            else
                return false;
        }

        // Generate a cross produect normal for a triangle
        Vector3 GenTriNormal(Vector3 t1, Vector3 t2, Vector3 t3)
        {
            Vector3 u = t2 - t1;
            Vector3 v = t3 - t1;

            Vector3 normal = math::CrossV3(u,v);

            return normal;
        }

        // Check to see if a Vector3 Point is within a 3 Vector3 Triangle
        bool inTriangle(Vector3 point, Vector3 tri1, Vector3 tri2, Vector3 tri3)
        {
            // Test to see if it is within an infinite prism that the triangle outlines.
            bool within_tri_prisim = SameSide(point, tri1, tri2, tri3) && SameSide(point, tri2, tri1, tri3)
                                     && SameSide(point, tri3, tri1, tri2);

            // If it isn't it will never be on the triangle
            if (!within_tri_prisim)
                return false;

            // Calulate Triangle's Normal
            Vector3 n = GenTriNormal(tri1, tri2, tri3);

            // Project the point onto this normal
            Vector3 proj = math::ProjV3(point, n);

            // If the distance from the triangle to the point is 0
            //	it lies on the triangle
            if (math::MagnitudeV3(proj) == 0)
                return true;
            else
                return false;
        }

        // Split a String into a string array at a given token
        inline void split(const std::string &in,
                          std::vector<std::string> &out,
                          std::string token)
        {
            out.clear();

            std::string temp;

            for (int i = 0; i < int(in.size()); i++)
            {
                std::string test = in.substr(i, token.size());

                if (test == token)
                {
                    if (!temp.empty())
                    {
                        out.push_back(temp);
                        temp.clear();
                        i += (int)token.size() - 1;
                    }
                    else
                    {
                        out.push_back("");
                    }
                }
                else if (i + token.size() >= in.size())
                {
                    temp += in.substr(i, token.size());
                    out.push_back(temp);
                    break;
                }
                else
                {
                    temp += in[i];
                }
            }
        }

        // Get tail of string after first token and possibly following spaces
        inline std::string tail(const std::string &in)
        {
            size_t token_start = in.find_first_not_of(" \t");
            size_t space_start = in.find_first_of(" \t", token_start);
            size_t tail_start = in.find_first_not_of(" \t", space_start);
            size_t tail_end = in.find_last_not_of(" \t");
            if (tail_start != std::string::npos && tail_end != std::string::npos)
            {
                return in.substr(tail_start, tail_end - tail_start + 1);
            }
            else if (tail_start != std::string::npos)
            {
                return in.substr(tail_start);
            }
            return "";
        }

        // Get first token of string
        inline std::string firstToken(const std::string &in)
        {
            if (!in.empty())
            {
                size_t token_start = in.find_first_not_of(" \t");
                size_t token_end = in.find_first_of(" \t", token_start);
                if (token_start != std::string::npos && token_end != std::string::npos)
                {
                    return in.substr(token_start, token_end - token_start);
                }
                else if (token_start != std::string::npos)
                {
                    return in.substr(token_start);
                }
            }
            return "";
        }

        // Get element at given index position
        template <class T>
        inline const T & getElement(const std::vector<T> &elements, std::string &index)
        {
            int idx = std::stoi(index);
            if (idx < 0)
                idx = int(elements.size()) + idx;
            else
                idx--;
            return elements[idx];
        }
    }

    // Class: Loader
    //
    // Description: The OBJ Model Loader
    class Loader
    {
    public:
        // Default Constructor
        Loader()
        {

        }
        ~Loader()
        {
            LoadedMeshes.clear();
        }

        // Load a file into the loader
        //
        // If file is loaded return true
        //
        // If the file is unable to be found
        // or unable to be loaded return false
        bool LoadFile(std::string Path)
        {
            // If the file is not an .obj file return false
            if (Path.substr(Path.size() - 4, 4) != ".obj")
                return false;


            std::ifstream file(Path);

            if (!file.is_open())
                return false;

            LoadedMeshes.clear();
            LoadedVertices.clear();
            LoadedIndices.clear();

            std::vector<Vector3> Positions;
            std::vector<Vector2> TCoords;
            std::vector<Vector3> Normals;

            std::vector<Vertex> Vertices;
            std::vector<unsigned int> Indices;

            std::vector<std::string> MeshMatNames;

            bool listening = false;
            std::string meshname;

            Mesh tempMesh;

#ifdef OBJL_CONSOLE_OUTPUT
            const unsigned int outputEveryNth = 1000;
            unsigned int outputIndicator = outputEveryNth;
#endif

            std::string curline;
            while (std::getline(file, curline))
            {
#ifdef OBJL_CONSOLE_OUTPUT
                if ((outputIndicator = ((outputIndicator + 1) % outputEveryNth)) == 1)
                {
                    if (!meshname.empty())
                    {
                        std::cout
                                << "\r- " << meshname
                                << "\t| vertices > " << Positions.size()
                                << "\t| texcoords > " << TCoords.size()
                                << "\t| normals > " << Normals.size()
                                << "\t| triangles > " << (Vertices.size() / 3)
                                << (!MeshMatNames.empty() ? "\t| material: " + MeshMatNames.back() : "");
                    }
                }
#endif

                // Generate a Mesh Object or Prepare for an object to be created
                if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g" || curline[0] == 'g')
                {
                    if (!listening)
                    {
                        listening = true;

                        if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g")
                        {
                            meshname = algorithm::tail(curline);
                        }
                        else
                        {
                            meshname = "unnamed";
                        }
                    }
                    else
                    {
                        // Generate the mesh to put into the array

                        if (!Indices.empty() && !Vertices.empty())
                        {
                            // Create Mesh
                            tempMesh = Mesh(Vertices, Indices);
                            tempMesh.MeshName = meshname;

                            // Insert Mesh
                            LoadedMeshes.push_back(tempMesh);

                            // Cleanup
                            Vertices.clear();
                            Indices.clear();
                            meshname.clear();

                            meshname = algorithm::tail(curline);
                        }
                        else
                        {
                            if (algorithm::firstToken(curline) == "o" || algorithm::firstToken(curline) == "g")
                            {
                                meshname = algorithm::tail(curline);
                            }
                            else
                            {
                                meshname = "unnamed";
                            }
                        }
                    }
#ifdef OBJL_CONSOLE_OUTPUT
                    std::cout << std::endl;
                    outputIndicator = 0;
#endif
                }
                // Generate a Vertex Position
                if (algorithm::firstToken(curline) == "v")
                {
                    std::vector<std::string> spos;
                    Vector3 vpos;
                    algorithm::split(algorithm::tail(curline), spos, " ");

                    vpos.X = std::stof(spos[0]);
                    vpos.Y = std::stof(spos[1]);
                    vpos.Z = std::stof(spos[2]);

                    Positions.push_back(vpos);
                }
                // Generate a Vertex Texture Coordinate
                if (algorithm::firstToken(curline) == "vt")
                {
                    std::vector<std::string> stex;
                    Vector2 vtex;
                    algorithm::split(algorithm::tail(curline), stex, " ");

                    vtex.X = std::stof(stex[0]);
                    vtex.Y = std::stof(stex[1]);

                    TCoords.push_back(vtex);
                }
                // Generate a Vertex Normal;
                if (algorithm::firstToken(curline) == "vn")
                {
                    std::vector<std::string> snor;
                    Vector3 vnor;
                    algorithm::split(algorithm::tail(curline), snor, " ");

                    vnor.X = std::stof(snor[0]);
                    vnor.Y = std::stof(snor[1]);
                    vnor.Z = std::stof(snor[2]);

                    Normals.push_back(vnor);
                }
                // Generate a Face (vertices & indices)
                if (algorithm::firstToken(curline) == "f")
                {
                    // Generate the vertices
                    std::vector<Vertex> vVerts;
                    GenVerticesFromRawOBJ(vVerts, Positions, TCoords, Normals, curline);

                    // Add Vertices
                    for (int i = 0; i < int(vVerts.size()); i++)
                    {
                        Vertices.push_back(vVerts[i]);

                        LoadedVertices.push_back(vVerts[i]);
                    }

                    std::vector<unsigned int> iIndices;

                    VertexTriangluation(iIndices, vVerts);

                    // Add Indices
                    for (int i = 0; i < int(iIndices.size()); i++)
                    {
                        unsigned int indnum = (unsigned int)((Vertices.size()) - vVerts.size()) + iIndices[i];
                        Indices.push_back(indnum);

                        indnum = (unsigned int)((LoadedVertices.size()) - vVerts.size()) + iIndices[i];
                        LoadedIndices.push_back(indnum);

                    }
                }
                // Get Mesh Material Name
                if (algorithm::firstToken(curline) == "usemtl")
                {
                    MeshMatNames.push_back(algorithm::tail(curline));

                    // Create new Mesh, if Material changes within a group
                    if (!Indices.empty() && !Vertices.empty())
                    {
                        // Create Mesh
                        tempMesh = Mesh(Vertices, Indices);
                        tempMesh.MeshName = meshname;
                        int i = 2;
                        while(1) {
                            tempMesh.MeshName = meshname + "_" + std::to_string(i);

                            for (auto &m : LoadedMeshes)
                                if (m.MeshName == tempMesh.MeshName)
                                    continue;
                            break;
                        }

                        // Insert Mesh
                        LoadedMeshes.push_back(tempMesh);

                        // Cleanup
                        Vertices.clear();
                        Indices.clear();
                    }

#ifdef OBJL_CONSOLE_OUTPUT
                    outputIndicator = 0;
#endif
                }
                // Load Materials
                if (algorithm::firstToken(curline) == "mtllib")
                {
                    // Generate LoadedMaterial

                    // Generate a path to the material file
                    std::vector<std::string> temp;
                    algorithm::split(Path, temp, "/");

                    std::string pathtomat = "";

                    if (temp.size() != 1)
                    {
                        for (int i = 0; i < temp.size() - 1; i++)
                        {
                            pathtomat += temp[i] + "/";
                        }
                    }


                    pathtomat += algorithm::tail(curline);

#ifdef OBJL_CONSOLE_OUTPUT
                    std::cout << std::endl << "- find materials in: " << pathtomat << std::endl;
#endif

                    // Load Materials
                    LoadMaterials(pathtomat);
                }
            }

#ifdef OBJL_CONSOLE_OUTPUT
            std::cout << std::endl;
#endif

            // Deal with last mesh

            if (!Indices.empty() && !Vertices.empty())
            {
                // Create Mesh
                tempMesh = Mesh(Vertices, Indices);
                tempMesh.MeshName = meshname;

                // Insert Mesh
                LoadedMeshes.push_back(tempMesh);
            }

            file.close();

            // Set Materials for each Mesh
            for (int i = 0; i < MeshMatNames.size(); i++)
            {
                std::string matname = MeshMatNames[i];

                // Find corresponding material name in loaded materials
                // when found copy material variables into mesh material
                for (int j = 0; j < LoadedMaterials.size(); j++)
                {
                    if (LoadedMaterials[j].name == matname)
                    {
                        LoadedMeshes[i].MeshMaterial = LoadedMaterials[j];
                        break;
                    }
                }
            }

            if (LoadedMeshes.empty() && LoadedVertices.empty() && LoadedIndices.empty())
            {
                return false;
            }
            else
            {
                return true;
            }
        }

        // Loaded Mesh Objects
        std::vector<Mesh> LoadedMeshes;
        // Loaded Vertex Objects
        std::vector<Vertex> LoadedVertices;
        // Loaded Index Positions
        std::vector<unsigned int> LoadedIndices;
        // Loaded Material Objects
        std::vector<Material> LoadedMaterials;

    private:
        // Generate vertices from a list of positions,
        //	tcoords, normals and a face line
        void GenVerticesFromRawOBJ(std::vector<Vertex>& oVerts,
                                   const std::vector<Vector3>& iPositions,
                                   const std::vector<Vector2>& iTCoords,
                                   const std::vector<Vector3>& iNormals,
                                   std::string icurline)
        {
            std::vector<std::string> sface, svert;
            Vertex vVert;
            algorithm::split(algorithm::tail(icurline), sface, " ");

            bool noNormal = false;

            // For every given vertex do this
            for (int i = 0; i < int(sface.size()); i++)
            {
                // See What type the vertex is.
                int vtype;

                algorithm::split(sface[i], svert, "/");

                // Check for just position - v1
                if (svert.size() == 1)
                {
                    // Only position
                    vtype = 1;
                }

                // Check for position & texture - v1/vt1
                if (svert.size() == 2)
                {
                    // Position & Texture
                    vtype = 2;
                }

                // Check for Position, Texture and Normal - v1/vt1/vn1
                // or if Position and Normal - v1//vn1
                if (svert.size() == 3)
                {
                    if (svert[1] != "")
                    {
                        // Position, Texture, and Normal
                        vtype = 4;
                    }
                    else
                    {
                        // Position & Normal
                        vtype = 3;
                    }
                }

                // Calculate and store the vertex
                switch (vtype)
                {
                    case 1: // P
                    {
                        vVert.Position = algorithm::getElement(iPositions, svert[0]);
                        vVert.TextureCoordinate = Vector2(0, 0);
                        noNormal = true;
                        oVerts.push_back(vVert);
                        break;
                    }
                    case 2: // P/T
                    {
                        vVert.Position = algorithm::getElement(iPositions, svert[0]);
                        vVert.TextureCoordinate = algorithm::getElement(iTCoords, svert[1]);
                        noNormal = true;
                        oVerts.push_back(vVert);
                        break;
                    }
                    case 3: // P//N
                    {
                        vVert.Position = algorithm::getElement(iPositions, svert[0]);
                        vVert.TextureCoordinate = Vector2(0, 0);
                        vVert.Normal = algorithm::getElement(iNormals, svert[2]);
                        oVerts.push_back(vVert);
                        break;
                    }
                    case 4: // P/T/N
                    {
                        vVert.Position = algorithm::getElement(iPositions, svert[0]);
                        vVert.TextureCoordinate = algorithm::getElement(iTCoords, svert[1]);
                        vVert.Normal = algorithm::getElement(iNormals, svert[2]);
                        oVerts.push_back(vVert);
                        break;
                    }
                    default:
                    {
                        break;
                    }
                }
            }

            // take care of missing normals
            // these may not be truly acurate but it is the
            // best they get for not compiling a mesh with normals
            if (noNormal)
            {
                Vector3 A = oVerts[0].Position - oVerts[1].Position;
                Vector3 B = oVerts[2].Position - oVerts[1].Position;

                Vector3 normal = math::CrossV3(A, B);

                for (int i = 0; i < int(oVerts.size()); i++)
                {
                    oVerts[i].Normal = normal;
                }
            }
        }

        // Triangulate a list of vertices into a face by printing
        //	inducies corresponding with triangles within it
        void VertexTriangluation(std::vector<unsigned int>& oIndices,
                                 const std::vector<Vertex>& iVerts)
        {
            // If there are 2 or less verts,
            // no triangle can be created,
            // so exit
            if (iVerts.size() < 3)
            {
                return;
            }
            // If it is a triangle no need to calculate it
            if (iVerts.size() == 3)
            {
                oIndices.push_back(0);
                oIndices.push_back(1);
                oIndices.push_back(2);
                return;
            }

            // Create a list of vertices
            std::vector<Vertex> tVerts = iVerts;

            while (true)
            {
                // For every vertex
                for (int i = 0; i < int(tVerts.size()); i++)
                {
                    // pPrev = the previous vertex in the list
                    Vertex pPrev;
                    if (i == 0)
                    {
                        pPrev = tVerts[tVerts.size() - 1];
                    }
                    else
                    {
                        pPrev = tVerts[i - 1];
                    }

                    // pCur = the current vertex;
                    Vertex pCur = tVerts[i];

                    // pNext = the next vertex in the list
                    Vertex pNext;
                    if (i == tVerts.size() - 1)
                    {
                        pNext = tVerts[0];
                    }
                    else
                    {
                        pNext = tVerts[i + 1];
                    }

                    // Check to see if there are only 3 verts left
                    // if so this is the last triangle
                    if (tVerts.size() == 3)
                    {
                        // Create a triangle from pCur, pPrev, pNext
                        for (int j = 0; j < int(tVerts.size()); j++)
                        {
                            if (iVerts[j].Position == pCur.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == pPrev.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == pNext.Position)
                                oIndices.push_back(j);
                        }

                        tVerts.clear();
                        break;
                    }
                    if (tVerts.size() == 4)
                    {
                        // Create a triangle from pCur, pPrev, pNext
                        for (int j = 0; j < int(iVerts.size()); j++)
                        {
                            if (iVerts[j].Position == pCur.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == pPrev.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == pNext.Position)
                                oIndices.push_back(j);
                        }

                        Vector3 tempVec;
                        for (int j = 0; j < int(tVerts.size()); j++)
                        {
                            if (tVerts[j].Position != pCur.Position
                                && tVerts[j].Position != pPrev.Position
                                && tVerts[j].Position != pNext.Position)
                            {
                                tempVec = tVerts[j].Position;
                                break;
                            }
                        }

                        // Create a triangle from pCur, pPrev, pNext
                        for (int j = 0; j < int(iVerts.size()); j++)
                        {
                            if (iVerts[j].Position == pPrev.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == pNext.Position)
                                oIndices.push_back(j);
                            if (iVerts[j].Position == tempVec)
                                oIndices.push_back(j);
                        }

                        tVerts.clear();
                        break;
                    }

                    // If Vertex is not an interior vertex
                    float angle = math::AngleBetweenV3(pPrev.Position - pCur.Position, pNext.Position - pCur.Position) * (180 / 3.14159265359);
                    if (angle <= 0 && angle >= 180)
                        continue;

                    // If any vertices are within this triangle
                    bool inTri = false;
                    for (int j = 0; j < int(iVerts.size()); j++)
                    {
                        if (algorithm::inTriangle(iVerts[j].Position, pPrev.Position, pCur.Position, pNext.Position)
                            && iVerts[j].Position != pPrev.Position
                            && iVerts[j].Position != pCur.Position
                            && iVerts[j].Position != pNext.Position)
                        {
                            inTri = true;
                            break;
                        }
                    }
                    if (inTri)
                        continue;

                    // Create a triangle from pCur, pPrev, pNext
                    for (int j = 0; j < int(iVerts.size()); j++)
                    {
                        if (iVerts[j].Position == pCur.Position)
                            oIndices.push_back(j);
                        if (iVerts[j].Position == pPrev.Position)
                            oIndices.push_back(j);
                        if (iVerts[j].Position == pNext.Position)
                            oIndices.push_back(j);
                    }

                    // Delete pCur from the list
                    for (int j = 0; j < int(tVerts.size()); j++)
                    {
                        if (tVerts[j].Position == pCur.Position)
                        {
                            tVerts.erase(tVerts.begin() + j);
                            break;
                        }
                    }

                    // reset i to the start
                    // -1 since loop will add 1 to it
                    i = -1;
                }

                // if no triangles were created
                if (oIndices.size() == 0)
                    break;

                // if no more vertices
                if (tVerts.size() == 0)
                    break;
            }
        }

        // Load Materials from .mtl file
        bool LoadMaterials(std::string path)
        {
            // If the file is not a material file return false
            if (path.substr(path.size() - 4, path.size()) != ".mtl")
                return false;

            std::ifstream file(path);

            // If the file is not found return false
            if (!file.is_open())
                return false;

            Material tempMaterial;

            bool listening = false;

            // Go through each line looking for material variables
            std::string curline;
            while (std::getline(file, curline))
            {
                // new material and material name
                if (algorithm::firstToken(curline) == "newmtl")
                {
                    if (!listening)
                    {
                        listening = true;

                        if (curline.size() > 7)
                        {
                            tempMaterial.name = algorithm::tail(curline);
                        }
                        else
                        {
                            tempMaterial.name = "none";
                        }
                    }
                    else
                    {
                        // Generate the material

                        // Push Back loaded Material
                        LoadedMaterials.push_back(tempMaterial);

                        // Clear Loaded Material
                        tempMaterial = Material();

                        if (curline.size() > 7)
                        {
                            tempMaterial.name = algorithm::tail(curline);
                        }
                        else
                        {
                            tempMaterial.name = "none";
                        }
                    }
                }
                // Ambient Color
                if (algorithm::firstToken(curline) == "Ka")
                {
                    std::vector<std::string> temp;
                    algorithm::split(algorithm::tail(curline), temp, " ");

                    if (temp.size() != 3)
                        continue;

                    tempMaterial.Ka.X = std::stof(temp[0]);
                    tempMaterial.Ka.Y = std::stof(temp[1]);
                    tempMaterial.Ka.Z = std::stof(temp[2]);
                }
                // Diffuse Color
                if (algorithm::firstToken(curline) == "Kd")
                {
                    std::vector<std::string> temp;
                    algorithm::split(algorithm::tail(curline), temp, " ");

                    if (temp.size() != 3)
                        continue;

                    tempMaterial.Kd.X = std::stof(temp[0]);
                    tempMaterial.Kd.Y = std::stof(temp[1]);
                    tempMaterial.Kd.Z = std::stof(temp[2]);
                }
                // Specular Color
                if (algorithm::firstToken(curline) == "Ks")
                {
                    std::vector<std::string> temp;
                    algorithm::split(algorithm::tail(curline), temp, " ");

                    if (temp.size() != 3)
                        continue;

                    tempMaterial.Ks.X = std::stof(temp[0]);
                    tempMaterial.Ks.Y = std::stof(temp[1]);
                    tempMaterial.Ks.Z = std::stof(temp[2]);
                }
                // Specular Exponent
                if (algorithm::firstToken(curline) == "Ns")
                {
                    tempMaterial.Ns = std::stof(algorithm::tail(curline));
                }
                // Optical Density
                if (algorithm::firstToken(curline) == "Ni")
                {
                    tempMaterial.Ni = std::stof(algorithm::tail(curline));
                }
                // Dissolve
                if (algorithm::firstToken(curline) == "d")
                {
                    tempMaterial.d = std::stof(algorithm::tail(curline));
                }
                // Illumination
                if (algorithm::firstToken(curline) == "illum")
                {
                    tempMaterial.illum = std::stoi(algorithm::tail(curline));
                }
                // Ambient Texture Map
                if (algorithm::firstToken(curline) == "map_Ka")
                {
                    tempMaterial.map_Ka = algorithm::tail(curline);
                }
                // Diffuse Texture Map
                if (algorithm::firstToken(curline) == "map_Kd")
                {
                    tempMaterial.map_Kd = algorithm::tail(curline);
                }
                // Specular Texture Map
                if (algorithm::firstToken(curline) == "map_Ks")
                {
                    tempMaterial.map_Ks = algorithm::tail(curline);
                }
                // Specular Hightlight Map
                if (algorithm::firstToken(curline) == "map_Ns")
                {
                    tempMaterial.map_Ns = algorithm::tail(curline);
                }
                // Alpha Texture Map
                if (algorithm::firstToken(curline) == "map_d")
                {
                    tempMaterial.map_d = algorithm::tail(curline);
                }
                // Bump Map
                if (algorithm::firstToken(curline) == "map_Bump" || algorithm::firstToken(curline) == "map_bump" || algorithm::firstToken(curline) == "bump")
                {
                    tempMaterial.map_bump = algorithm::tail(curline);
                }
            }

            // Deal with last material

            // Push Back loaded Material
            LoadedMaterials.push_back(tempMaterial);

            // Test to see if anything was loaded
            // If not return false
            if (LoadedMaterials.empty())
                return false;
                // If so return true
            else
                return true;
        }
    };
}
#endif //RASTERIZER_OBJ_LOADER_H

```
线性代数使用Eigen库

三角形类

```cpp
#ifndef TINYRENDERER_TRIANGLE_H
#define TINYRENDERER_TRIANGLE_H
#include <Eigen/Eigen>
using namespace Eigen;
class Triangle{
public:
    Eigen::Vector4f globalCoords[3];
    Eigen::Vector3f color[3];
    Eigen::Vector2f texCoords[3];
    Eigen::Vector3f normal[3];
    Eigen::Vector3f screenCoords[3];
    Triangle();

    void setGlobalCoords(int ind, Eigen::Vector4f ver);
    void setNormal(int ind, Eigen::Vector3f n);
    void setTexCoord(int ind,Eigen::Vector2f uv);
    void setScreenCoord(int ind,int width,int height);
};

#endif //TINYRENDERER_TRIANGLE_H

```

```cpp
#include "Triangle.h"

Triangle::Triangle() {
    globalCoords[0] << 0,0,0,1;
    globalCoords[1] << 0,0,0,1;
    globalCoords[2] << 0,0,0,1;

    color[0] << 0.0, 0.0, 0.0;
    color[1] << 0.0, 0.0, 0.0;
    color[2] << 0.0, 0.0, 0.0;

    texCoords[0] << 0.0, 0.0;
    texCoords[1] << 0.0, 0.0;
    texCoords[2] << 0.0, 0.0;
}

void Triangle::setGlobalCoords(int ind, Vector4f ver){
    globalCoords[ind] = ver;
}
void Triangle::setNormal(int ind, Vector3f n){
    normal[ind] = n;
}
void Triangle::setTexCoord(int ind, Vector2f uv) {
    texCoords[ind] = uv;
}
// 简单实现正交投影
Vector3f world2screen(Vector4f globalCoord,int width,int height) {
    return Vector3f(int((globalCoord.x()+1.)*width/2.+.5), int((globalCoord.y()+1.)*height/2.+.5), globalCoord.z());
}
void Triangle::setScreenCoord(int ind,int width,int height) {
    screenCoords[ind] = world2screen(this->globalCoords[ind],width,height);
}

```
模型类

```cpp
#ifndef __MODEL_H__
#define __MODEL_H__

#include <vector>
#include <Eigen/Eigen>
#include "Triangle.h"

class Model {
private:
public:
    explicit Model(const char *filename);
    ~Model();
    std::vector<Triangle> triangleList;

};

#endif //__MODEL_H__
```

```cpp
#include "model.h"
#include "thirdParty/OBJ_Loader.h"
// 加载模型就直接用教程的代码了！
Model::Model(const char *filename) {
    objl::Loader Loader;
    Loader.LoadFile(filename);
    std::cout << "?";

    for (const auto &mesh: Loader.LoadedMeshes){
        for(int i=0;i<mesh.Vertices.size();i+=3)
        {

            Triangle * t = new Triangle;
            for(int j=0;j<3;j++)
            {
                t->setGlobalCoords(j, Vector4f(mesh.Vertices[i + j].Position.X, mesh.Vertices[i + j].Position.Y,mesh.Vertices[i + j].Position.Z, 1.0));
                t->setNormal(j,Vector3f(mesh.Vertices[i+j].Normal.X,mesh.Vertices[i+j].Normal.Y,mesh.Vertices[i+j].Normal.Z));
                t->setTexCoord(j,Vector2f(mesh.Vertices[i+j].TextureCoordinate.X, mesh.Vertices[i+j].TextureCoordinate.Y));
            }
            this->triangleList.push_back(*t);
        }
    }
}

Model::~Model() {
}

```

已经告诉了使用zbuffer，其实就是把处于后边的物体就不需要渲染了，在背面剔除后，删掉了不需要处理的三角形，但是在像素层面，位于前面的颜色应该把后边的颜色挡住
首先来定义一个zbuffer，我没有使用教程中的一位数组表示，因为我不希望代码理解起来过于复杂
```cpp
    // 定义一个zbuffer，并设置为无穷小
    std::unique_ptr<std::vector<std::vector<float>>> zBuffer = std::make_unique<std::vector<std::vector<float>>>(width, std::vector<float>(height));
    auto * zBuffer = new std::vector<std::vector<float>>(width, std::vector<float>(std::numeric_limits<float>::lowest()));
```
在这种情况下，绘制像素前要先判断当前想要绘制的颜色是否被挡住，至于是大于号还是小于号，看如何定义，当前模型是z越大离屏幕越近

```cpp
	double alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
	double beta  = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
	double gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
	if (alpha<0 || beta<0 || gamma<0) continue; // 说明当前像素不在三角形内部
	float barycentricZ = alpha*triangle.screenCoords[0].z() + beta*triangle.screenCoords[1].z() + gamma*triangle.screenCoords[2].z();
	// zbuffer中缓存的渲染物体距离小于当前渲染物体的距离时，才覆盖渲染
	if (x<width && y < height && zBuffer->at(x).at(y) < barycentricZ){
	    zBuffer->at(x).at(y) = barycentricZ;
	    framebuffer.set(x,y,color);
	}
```
当前的整体代码如下

```cpp
#include "thirdParty/tgaimage.h"
#include "model.h"
#include <vector>
#include <cmath>
#include <iostream>

constexpr TGAColor white   = {255, 255, 255, 255};
constexpr TGAColor green   = {  0, 255,   0, 255};
constexpr TGAColor red     = {  255,   0, 0, 255};
constexpr TGAColor blue    = {255, 128,  64, 255};
constexpr TGAColor yellow  = {  0, 200, 255, 255};
constexpr static int width  = 2560;
constexpr static int height = 1920;
// 画线尝试1
void drawLine_first(int ax, int ay, int bx, int by, TGAImage &img, TGAColor color){
    for(float t = 0;t<=1;t+=0.02){
        int x = std::round(ax + t * (bx - ax)); // round会进行四舍五入
        int y = std::round(ay + t * (by - ay));
        img.set(x,y,color);
    }
}
// 画线尝试2
void drawLine_second(int ax, int ay, int bx, int by, TGAImage &img, TGAColor color){
    if (ax>bx) { // make it left−to−right
        std::swap(ax, bx);
        std::swap(ay, by);
    }
    for (int x = ax ; x<= bx; x++) { // 不再以t控制，而是以x的进行进行控制，保证了水平方向上不会有空隙
        // 如果不加强制转换，当分子分母都是整数时，计算结果的小数部分会被截断
        float t = (x-ax)/static_cast<float>(bx-ax); // 变换了形式，表示出当x移动一格时，t是多少，
        int y = std::round( ay + (by-ay)*t );
        img.set(x, y, color);
    }
}
// 画线尝试3
void drawLine_third(int ax, int ay, int bx, int by, TGAImage &img, TGAColor color){
    bool steep = std::abs(ax-bx) < std::abs(ay-by);
    if (steep) { // if the drawLine is steep, we transpose the image
        std::swap(ax, ay);
        std::swap(bx, by);
    }
    if (ax>bx) { // make it left−to−right
        std::swap(ax, bx);
        std::swap(ay, by);
    }
    for (int x = ax ; x<= bx; x++) { // 不再以t控制，而是以x的进行进行控制，保证了水平方向上不会有空隙
        // 如果不加强制转换，当分子分母都是整数时，计算结果的小数部分会被截断
        float t = (x-ax)/static_cast<float>(bx-ax); // 变换了形式，表示出当x移动一格时，t是多少，
        int y = std::round( ay + (by-ay)*t );
        if (steep) // if transposed, de−transpose
            img.set(y, x, color);
        else
            img.set(x, y, color);
    }
}
// 最终版本 对计算进行了优化
void drawLine(int ax, int ay, int bx, int by, TGAImage &framebuffer, TGAColor color) {
    bool steep = std::abs(ax-bx) < std::abs(ay-by);
    if (steep) { // if the drawLine is steep, we transpose the image
        std::swap(ax, ay);
        std::swap(bx, by);
    }
    if (ax>bx) { // make it left−to−right
        std::swap(ax, bx);
        std::swap(ay, by);
    }
    int y = ay;
    int ierror = 0;
    for (int x=ax; x<=bx; x++) {
        if (steep) // if transposed, de−transpose
            framebuffer.set(y, x, color);
        else
            framebuffer.set(x, y, color);
        ierror += 2 * std::abs(by-ay);
        y += (by > ay ? 1 : -1) * (ierror > bx - ax);
        ierror -= 2 * (bx-ax)   * (ierror > bx - ax);
    }
}
// 三角形面积，可能返回负数，表示背对屏幕
double signed_triangle_area(int ax, int ay, int bx, int by, int cx, int cy) {
    return .5*((by-ay)*(bx+ax) + (cy-by)*(cx+bx) + (ay-cy)*(ax+cx));
}
// 绘制一个三角形
void drawTriangle(Triangle triangle, TGAImage &framebuffer, std::vector<std::vector<float>> * zBuffer,TGAColor color) {
    float ax = triangle.screenCoords[0].x();
    float ay = triangle.screenCoords[0].y();
    float bx = triangle.screenCoords[1].x();
    float by = triangle.screenCoords[1].y();
    float cx = triangle.screenCoords[2].x();
    float cy = triangle.screenCoords[2].y();
    float bbminx = std::min(std::min(ax, bx), cx);
    float bbminy = std::min(std::min(ay, by), cy);
    float bbmaxx = std::max(std::max(ax, bx), cx);
    float bbmaxy = std::max(std::max(ay, by), cy);

    // 如果面积为负数，背对屏幕，被裁剪
    double total_area = signed_triangle_area(ax, ay, bx, by, cx, cy);
    if (total_area<1) return;

#pragma omp parallel for
    for (int x=bbminx; x<=bbmaxx; x++) {
        for (int y=bbminy; y<=bbmaxy; y++) {
            double alpha = signed_triangle_area(x, y, bx, by, cx, cy) / total_area;
            double beta  = signed_triangle_area(x, y, cx, cy, ax, ay) / total_area;
            double gamma = signed_triangle_area(x, y, ax, ay, bx, by) / total_area;
            if (alpha<0 || beta<0 || gamma<0) continue; // 说明当前像素不在三角形内部
            float barycentricZ = alpha*triangle.screenCoords[0].z() + beta*triangle.screenCoords[1].z() + gamma*triangle.screenCoords[2].z();
            // zbuffer中缓存的渲染物体距离小于当前渲染物体的距离时，才覆盖渲染
            if (x<width && y < height && zBuffer->at(x).at(y) < barycentricZ){
                zBuffer->at(x).at(y) = barycentricZ;
                framebuffer.set(x,y,color);
            }
        }
    }
}

int main() {
    auto * model = new Model("./obj/african_head/african_head.obj");
    TGAImage framebuffer(width, height, TGAImage::RGB);
    // 定义一个zBuffer,并设置全部数据为最小负数
    auto * zBuffer = new std::vector<std::vector<float>>(width, std::vector<float>(height,std::numeric_limits<float>::lowest()));
    // 遍历obj文件中的每个三角形
    for (Triangle triangle : model->triangleList) {
        // 将当前三角形的三个顶点都投影到屏幕
        for (int i = 0; i < 3; ++i) triangle.setScreenCoord(i,width,height);
        // 绘制三角形
        drawTriangle(triangle, framebuffer, zBuffer, TGAColor(rand()%255, rand()%255, rand()%255, 255));
    }
//    framebuffer.flip_vertically();
    framebuffer.write_tga_file("framebuffer.tga");
    return 0;
}
```

下一步就是把材质贴上去，也就是设置颜色时不再使用随机颜色，而是根据三个顶点的纹理坐标进行插值，获得一个像素点的纹理坐标，从纹理图片对应位置获取颜色来设置
首先得有一个承载材质的类，我这里使用的是TGAImage来读取图片,并把材质类作为Model的成员

```cpp
#ifndef TINYRENDERER_TEXTURE_H
#define TINYRENDERER_TEXTURE_H
#include <Eigen/Eigen>
#include "thirdParty/tgaimage.h"
class Texture{
private:
    TGAImage texture;

public:
    Texture(const std::string& name)
    {

        texture.read_tga_file("");
        width = texture.width();
        height = texture.height();
    }

    int width, height;

    TGAColor getColor(float u, float v)
    {
        auto u_img = u * width;
        auto v_img = (1 - v) * height;
        TGAColor color = texture.get(v_img, u_img);
        return color;
    }
};
#endif //TINYRENDERER_TEXTURE_H
```
在main中首先对uv坐标进行插值，之后在设置像素颜色时，通过插值的uv坐标，到uv图中找对应位置的颜色

```cpp
            float texU = alpha*triangle.texCoords[0].x() + beta*triangle.texCoords[1].x() + gamma*triangle.texCoords[2].x();
            float texV = alpha*triangle.texCoords[0].y() + beta*triangle.texCoords[1].y() + gamma*triangle.texCoords[2].y();
            // zbuffer中缓存的渲染物体距离小于当前渲染物体的距离时，才覆盖渲染
            if (x<width && y < height && zBuffer->at(x).at(y) < barycentricZ){
                zBuffer->at(x).at(y) = barycentricZ;
                framebuffer.set(x,y,texture.getColor(texU,texV));
            }
```
生成效果如下图所示
![请添加图片描述](20299b964a794459b9696f742506670e.png)
到目前为止我自己的实现可以在github的分支结点中找到：https://github.com/sdpyy1/CppLearn/tree/56841b79fe7c74bce1d9210f1a42e2a3ca019768/tinyrenderer
# Lesson 4: Perspective projection
这里我不希望只完成他课程的简单情况，我直接把MVP矩阵+视口变换全部封装了，详情可查看我的仓库，下边是主要代码

```cpp
#include "model.h"
#include "thirdParty/OBJ_Loader.h"
Model::Model(const char * objFileName,const char * texFileName) : texture(texFileName){
    objl::Loader Loader;
    Loader.LoadFile(objFileName);
    this->modelMatrix = Eigen::Matrix4f::Identity();
    this->viewMatrix = Eigen::Matrix4f::Identity();
    this->projectionMatrix = Eigen::Matrix4f::Identity();
    for (const auto &mesh: Loader.LoadedMeshes){
        for(int i=0;i<mesh.Vertices.size();i+=3)
        {
            Triangle t;
            for(int j=0;j<3;j++)
            {
                // 此处设置每个三角形的属性
                t.setGlobalCoord(j, Vector4f(mesh.Vertices[i + j].Position.X, mesh.Vertices[i + j].Position.Y,
                                              mesh.Vertices[i + j].Position.Z, 1.0));
                t.setNormal(j,Vector3f(mesh.Vertices[i+j].Normal.X,mesh.Vertices[i+j].Normal.Y,mesh.Vertices[i+j].Normal.Z));
                t.setTexCoord(j,Vector2f(mesh.Vertices[i+j].TextureCoordinate.X, mesh.Vertices[i+j].TextureCoordinate.Y));
                Matrix4f mvp = projectionMatrix * viewMatrix * modelMatrix;
            }
            this->triangleList.push_back(t);
        }
    }
}
// 将角度转换为弧度
constexpr float deg2rad(float degrees) {
    return degrees * M_PI / 180.0f;
}
// 生成绕 x, y, z 轴旋转的变换矩阵
Eigen::Matrix4f rotation(float angleX, float angleY, float angleZ) {
    // 分别计算绕 x, y, z 轴旋转的矩阵
    Eigen::Matrix4f rotationX = Eigen::Matrix4f::Identity();
    float radX = deg2rad(angleX);
    rotationX(1, 1) = std::cos(radX);
    rotationX(1, 2) = -std::sin(radX);
    rotationX(2, 1) = std::sin(radX);
    rotationX(2, 2) = std::cos(radX);

    Eigen::Matrix4f rotationY = Eigen::Matrix4f::Identity();
    float radY = deg2rad(angleY);
    rotationY(0, 0) = std::cos(radY);
    rotationY(0, 2) = std::sin(radY);
    rotationY(2, 0) = -std::sin(radY);
    rotationY(2, 2) = std::cos(radY);

    Eigen::Matrix4f rotationZ = Eigen::Matrix4f::Identity();
    float radZ = deg2rad(angleZ);
    rotationZ(0, 0) = std::cos(radZ);
    rotationZ(0, 1) = -std::sin(radZ);
    rotationZ(1, 0) = std::sin(radZ);
    rotationZ(1, 1) = std::cos(radZ);

    // 组合三个旋转矩阵，这里假设旋转顺序为 Z -> Y -> X
    Eigen::Matrix4f modelMatrix = rotationX * rotationY * rotationZ;
    return modelMatrix;
}
// 生成平移变换矩阵
Eigen::Matrix4f translation(float tx, float ty, float tz) {
    Eigen::Matrix4f translationMatrix = Eigen::Matrix4f::Identity();
    translationMatrix(0, 3) = tx;
    translationMatrix(1, 3) = ty;
    translationMatrix(2, 3) = tz;
    return translationMatrix;
}
// 生成缩放变换矩阵
Eigen::Matrix4f scaling(float sx, float sy, float sz) {
    Eigen::Matrix4f scalingMatrix = Eigen::Matrix4f::Identity();
    scalingMatrix(0, 0) = sx;
    scalingMatrix(1, 1) = sy;
    scalingMatrix(2, 2) = sz;
    return scalingMatrix;
}
// 视图变换矩阵
Eigen::Matrix4f get_view_matrix(Eigen::Vector3f eye_pos, Eigen::Vector3f target, Eigen::Vector3f up) {
    // TODO:还没理解怎么换的
    // 观察方向
    Vector3f z = (eye_pos - target).normalized();
    // 叉乘得右方向
    Vector3f r = z.cross(up).normalized();
    // 叉乘得上方向
    Vector3f u = z.cross(r).normalized();
    Eigen::Matrix4f translate;
    translate << r.x(),r.y(),r.z(),-r.dot(eye_pos),
                u.x(),u.y(),u.z(),-u.dot(eye_pos),
                -z.x(),-z.y(),-z.z(),z.dot(eye_pos),
                0,0,0,1;
    // 效果是将摄像机作为原点情况下各个点的坐标
    return translate;

}
Eigen::Matrix4f get_projection_matrix(float eye_fov, float aspect_ratio, float n, float f) {

    Eigen::Matrix4f projection = Eigen::Matrix4f::Identity();
    float t = -tan((eye_fov/360)*M_PI)*(abs(n)); //top
    float r = t/aspect_ratio;

    Eigen::Matrix4f Mp;//透视矩阵
    Mp <<
       n, 0, 0,   0,
            0, n, 0,   0,
            0, 0, n+f, -n*f,
            0, 0, 1,   0;
    Eigen::Matrix4f Mo_tran;//平移矩阵
    Mo_tran <<
            1, 0, 0, 0,
            0, 1, 0, 0,  //b=-t;
            0, 0, 1, -(n+f)/2 ,
            0, 0, 0, 1;
    Eigen::Matrix4f Mo_scale;//缩放矩阵
    Mo_scale <<
             1/r,     0,       0,       0,
            0,       1/t,     0,       0,
            0,       0,       2/(n-f), 0,
            0,       0,       0,       1;
    projection = (Mo_scale*Mo_tran)* Mp;//投影矩阵
    //这里一定要注意顺序，先透视再正交;正交里面先平移再缩放；否则做出来会是一条直线！
    return projection;
}
void Model::setModelTransformation(float angleX, float angleY, float angleZ, float tx, float ty, float tz, float sx, float sy, float sz){
    if (triangleList.empty()){
        std::cout << "模型未导入！"<<std::endl;
        return;
    }
    Eigen::Matrix4f rotationMatrix = rotation(angleX, angleY, angleZ);
    Eigen::Matrix4f translationMatrix = translation(tx, ty, tz);
    Eigen::Matrix4f scalingMatrix = scaling(sx, sy, sz);
    // 按缩放 -> 旋转 -> 平移的顺序组合变换矩阵
    modelMatrix = translationMatrix * rotationMatrix * scalingMatrix;
}
// 应用视图变换的函数
void Model::setViewTransformation(Eigen::Vector3f eye_pos, Eigen::Vector3f target, Eigen::Vector3f up) {
    viewMatrix = get_view_matrix(eye_pos,target,up);
}
// 应用透视变换的函数
void Model::setProjectionTransformation(float fovY, float aspectRatio, float near, float far) {
    projectionMatrix = get_projection_matrix(fovY, aspectRatio, near, far);
}

Matrix4f Model::getMVP(){
    return projectionMatrix * viewMatrix * modelMatrix;
}


Model::~Model() {
}

```
