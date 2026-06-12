+++date = '2025-11-02T20:46:56+08:00'
draft = false
title = '游戏引擎开发实践（Vulkan架构篇：Image）'
categories = ["Projects/游戏引擎"]
tags = ["Vulkan","RHI"]
+++

> 这里涉及的整套结构已经废弃，转为研究更轻薄的RHI层，放弃过度封装！


> 本文主要讲解GameEngine项目Vulkan封装，在渲染层只需要调用RHI层接口即可
# 总览
> 所有底层对象创建都需要使用xxxSpecification来说明创建需求，调用RHI接口函数，创建底层Vulkan对象

# Image

```c++
enum class ImageFormat
{
    None = 0,
    RED8UN,
    RED8UI,
    ...
    // Defaults
    Depth = DEPTH32F,
};
// 图片用途
enum class ImageUsage
{
	None = 0,
	Texture,
	Attachment,
	Storage,
	HostRead
};
// 图片说明书
struct ImageSpecification
{
	std::string DebugName;
	ImageFormat Format = ImageFormat::RGBA;  // 图片格式
	ImageUsage Usage = ImageUsage::Texture; // 用途
	bool Transfer = false; // 是否需要转移
	uint32_t Width = 1;
	uint32_t Height = 1;
	uint32_t Mips = 1; // mip多少层，在Vulkan中也需要自己指定
	uint32_t Layers = 1; // Layer，图层通常用于立方体纹理（6 个面）、数组纹理（多个图像的集合）等场景。
	bool CreateSampler = true;
};
```

```c++
class Image : public RendererResource
{
public:
	virtual ~Image() = default;

	virtual void Resize(const uint32_t width, const uint32_t height) = 0;
	virtual void Invalidate() = 0;
	virtual void Release() = 0;

	virtual uint32_t GetWidth() const = 0;
	virtual uint32_t GetHeight() const = 0;
	virtual glm::uvec2 GetSize() const = 0;
	virtual bool HasMips() const = 0;

	virtual float GetAspectRatio() const = 0;

	virtual ImageSpecification& GetSpecification() = 0;
	virtual const ImageSpecification& GetSpecification() const = 0;

	virtual Buffer GetBuffer() const = 0;
	virtual Buffer& GetBuffer() = 0;

	virtual uint64_t GetGPUMemoryUsage() const = 0; 

	virtual void CreatePerLayerImageViews() = 0;

	virtual uint64_t GetHash() const = 0;

	virtual void SetData(Buffer buffer) = 0;
	virtual void CopyToHostBuffer(Buffer& buffer) const = 0; 
};
class Image2D : public Image
{
public:
    static Ref<Image2D> Create(const ImageSpecification& specification, Buffer buffer = Buffer());
    virtual void Resize(const glm::uvec2& size) = 0;
    virtual bool IsValid() const = 0;
};
```

到VulkanImage2D后，创建过程

1. 处理图片用途

   声明图像的所有用途（需用按位或组合），类型为 `VkImageUsageFlags`，常见取值：

   - `VK_IMAGE_USAGE_SAMPLED_BIT`：可被采样器访问（作为纹理）。
   - `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT`：作为颜色附着（渲染目标）。
   - `VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT`：作为深度 / 模板附着。
   - `VK_IMAGE_USAGE_TRANSFER_SRC_BIT`/`VK_IMAGE_USAGE_TRANSFER_DST_BIT`：作为复制操作的源 / 目标。
   - `VK_IMAGE_USAGE_STORAGE_BIT`：作为存储图像（Compute Shader 读写）。

   用途需与后续操作匹配，否则会触发验证层错误。

```c++
VkImageUsageFlags usage = VK_IMAGE_USAGE_SAMPLED_BIT;
if (m_Specification.Usage == ImageUsage::Attachment) 
{
	if (Utils::IsDepthFormat(m_Specification.Format))
		usage |= VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
	else
		usage |= VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
}
if (m_Specification.Transfer || m_Specification.Usage == ImageUsage::Texture)
{
	usage |= VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
}
if (m_Specification.Usage == ImageUsage::Storage)
{
	usage |= VK_IMAGE_USAGE_STORAGE_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
}
```

2. VkImageCreateInfo

   ```c++
   VkImageCreateInfo imageCreateInfo = {};
   imageCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
   imageCreateInfo.imageType = VK_IMAGE_TYPE_2D;
   imageCreateInfo.format = vulkanFormat;
   imageCreateInfo.extent.width = m_Specification.Width;
   imageCreateInfo.extent.height = m_Specification.Height;
   imageCreateInfo.extent.depth = 1;
   imageCreateInfo.mipLevels = m_Specification.Mips;
   imageCreateInfo.arrayLayers = m_Specification.Layers;
   imageCreateInfo.samples = VK_SAMPLE_COUNT_1_BIT;
   imageCreateInfo.tiling = m_Specification.Usage == ImageUsage::HostRead ? VK_IMAGE_TILING_LINEAR : VK_IMAGE_TILING_OPTIMAL; // 内存布局
   imageCreateInfo.usage = usage;
   m_Info.MemoryAlloc = allocator.AllocateImage(imageCreateInfo, memoryUsage, m_Info.Image, &m_GPUAllocationSize);
   s_ImageReferences[m_Info.Image] = this;
   VKUtils::SetDebugUtilsObjectName(device, VK_OBJECT_TYPE_IMAGE, m_Specification.DebugName, m_Info.Image);
   ```

3. VkImageViewCreateInfo（默认创建的ImageView是包含Image所有（所有mip，所有layer）的ImageView）

   ```c++
   VkImageViewCreateInfo imageViewCreateInfo = {};
   imageViewCreateInfo.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
   imageViewCreateInfo.viewType = m_Specification.Layers > 1 ? VK_IMAGE_VIEW_TYPE_2D_ARRAY : VK_IMAGE_VIEW_TYPE_2D;
   imageViewCreateInfo.format = vulkanFormat;
   imageViewCreateInfo.flags = 0;
   imageViewCreateInfo.subresourceRange = {};
   imageViewCreateInfo.subresourceRange.aspectMask = aspectMask;
   imageViewCreateInfo.subresourceRange.baseMipLevel = 0;
   imageViewCreateInfo.subresourceRange.levelCount = m_Specification.Mips;
   imageViewCreateInfo.subresourceRange.baseArrayLayer = 0;
   imageViewCreateInfo.subresourceRange.layerCount = m_Specification.Layers;
   imageViewCreateInfo.image = m_Info.Image;
   VK_CHECK_RESULT(vkCreateImageView(device, &imageViewCreateInfo, nullptr, &m_Info.ImageView));
   VKUtils::SetDebugUtilsObjectName(device, VK_OBJECT_TYPE_IMAGE_VIEW, fmt::format("{} default image view", m_Specification.DebugName), m_Info.ImageView);
   ```

4. 采样器

   ```c++
   if (m_Specification.CreateSampler)
   {
   	VkSamplerCreateInfo samplerCreateInfo = {};
   	samplerCreateInfo.sType = VK_STRUCTURE_TYPE_SAMPLER_CREATE_INFO;
   	samplerCreateInfo.maxAnisotropy = 1.0f;
   	if (Utils::IsIntegerBased(m_Specification.Format))
   	{
   		samplerCreateInfo.magFilter = VK_FILTER_NEAREST;
   		samplerCreateInfo.minFilter = VK_FILTER_NEAREST;
   		samplerCreateInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_NEAREST;
   	}
   	else
   	{
   		samplerCreateInfo.magFilter = VK_FILTER_LINEAR;
   		samplerCreateInfo.minFilter = VK_FILTER_LINEAR;
   		samplerCreateInfo.mipmapMode = VK_SAMPLER_MIPMAP_MODE_LINEAR;
   	}
   
   	samplerCreateInfo.addressModeU = VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_EDGE;
   	samplerCreateInfo.addressModeV = samplerCreateInfo.addressModeU;
   	samplerCreateInfo.addressModeW = samplerCreateInfo.addressModeU;
   	samplerCreateInfo.mipLodBias = 0.0f;
   	samplerCreateInfo.minLod = 0.0f;
   	samplerCreateInfo.maxLod = 100.0f;
   	samplerCreateInfo.borderColor = VK_BORDER_COLOR_FLOAT_OPAQUE_WHITE;
   	m_Info.Sampler = Vulkan::CreateSampler(samplerCreateInfo);
   	VKUtils::SetDebugUtilsObjectName(device, VK_OBJECT_TYPE_SAMPLER, fmt::format("{} default sampler", m_Specification.DebugName), m_Info.Sampler);
   }
   ```

5. 设置图片默认布局 Storage和HostRead才会设置，其他图片都还是无布局状态，不过RenderPass设置可以设置附件的开始和结束布局

   ```c++
   if (m_Specification.Usage == ImageUsage::Storage) // General
   {
   	// Transition image to GENERAL layout
   	VkCommandBuffer commandBuffer = VulkanContext::GetCurrentDevice()->GetCommandBuffer(true);
   
   	VkImageSubresourceRange subresourceRange = {};
   	subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   	subresourceRange.baseMipLevel = 0;
   	subresourceRange.levelCount = m_Specification.Mips;
   	subresourceRange.layerCount = m_Specification.Layers;
   
   	Utils::InsertImageMemoryBarrier(commandBuffer, m_Info.Image,
   		0, 0,
   		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_GENERAL,
   		VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
   		subresourceRange);
   
   	VulkanContext::GetCurrentDevice()->FlushCommandBuffer(commandBuffer);
   }
   else if (m_Specification.Usage == ImageUsage::HostRead) // VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
   {
   	// Transition image to TRANSFER_DST layout
   	VkCommandBuffer commandBuffer = VulkanContext::GetCurrentDevice()->GetCommandBuffer(true);
   
   	VkImageSubresourceRange subresourceRange = {};
   	subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   	subresourceRange.baseMipLevel = 0;
   	subresourceRange.levelCount = m_Specification.Mips;
   	subresourceRange.layerCount = m_Specification.Layers;
   
   	Utils::InsertImageMemoryBarrier(commandBuffer, m_Info.Image,
   		0, 0,
   		VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
   		VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT,
   		subresourceRange);
   
   	VulkanContext::GetCurrentDevice()->FlushCommandBuffer(commandBuffer); // 会把命令提交并等待完成
   }
   ```

6. 资源描述符信息封装（用默认的构造写一个资源描述符）

   ```c++
   	void VulkanImage2D::UpdateDescriptor()
   	{
   		if (m_Specification.Format == ImageFormat::DEPTH24STENCIL8 ||
   			m_Specification.Format == ImageFormat::DEPTH32F ||
   			m_Specification.Format == ImageFormat::DEPTH32FSTENCIL8UINT) {
   			m_DescriptorImageInfo.imageLayout = VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL;
   		}
   		else if (m_Specification.Usage == ImageUsage::Storage) {
   			m_DescriptorImageInfo.imageLayout = VK_IMAGE_LAYOUT_GENERAL;
   		}
   		else if (m_Specification.Usage == ImageUsage::HostRead) {
   			m_DescriptorImageInfo.imageLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
   		}
   		else {
   			m_DescriptorImageInfo.imageLayout = VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL;
   		}
   
   		m_DescriptorImageInfo.imageView = m_Info.ImageView;
   
   		m_DescriptorImageInfo.sampler = m_Info.Sampler;
   	}
   ```

   > 另外Image类需要提供创建不同Mip不同Layer的ImageView的功能，用于不同的场景，比如Mip用于使用ComputerShader创建HZB，Layer用于CSM级联阴影，用一个Image的不同Layer表示不同的级联

# Texture

> Texture就是把Image再封装一层，用于纹理采样，另外封装了2D纹理和Cube纹理，后续还可以封装3D纹理，用于体积云等等

```c++
	struct TextureSpecification
	{
		ImageFormat Format = ImageFormat::RGBA;
		uint32_t Width = 1;
		uint32_t Height = 1;
		TextureWrap SamplerWrap = TextureWrap::Repeat;
		TextureFilter SamplerFilter = TextureFilter::Linear;

		bool GenerateMips = true;
		bool Storage = false;
		bool StoreLocally = false;

		std::string DebugName;
	};
	class Texture : public RendererResource
	{
	public:
		virtual ~Texture() {}

		virtual void Bind(uint32_t slot = 0) const = 0;

		virtual ImageFormat GetFormat() const = 0;
		virtual uint32_t GetWidth() const = 0;
		virtual uint32_t GetHeight() const = 0;
		virtual glm::uvec2 GetSize() const = 0;

		virtual uint32_t GetMipLevelCount() const = 0;
		virtual std::pair<uint32_t, uint32_t> GetMipSize(uint32_t mip) const = 0;

		virtual uint64_t GetHash() const = 0;

		virtual TextureType GetType() const = 0;
	};

	class Texture2D : public Texture
	{
	public:
		static Ref<Texture2D> Create(const TextureSpecification& specification);
		static Ref<Texture2D> Create(const TextureSpecification& specification, const std::filesystem::path& filepath);
		static Ref<Texture2D> Create(const TextureSpecification& specification, Buffer imageData);
		virtual void CreateFromFile(const TextureSpecification& specification, const std::filesystem::path& filepath) = 0;
		virtual void CreateFromBuffer(const TextureSpecification& specification, Buffer data = Buffer()) = 0;
		virtual void ReplaceFromFile(const TextureSpecification& specification, const std::filesystem::path& filepath) = 0;

		virtual void Resize(const glm::uvec2& size) = 0;
		virtual void Resize(const uint32_t width, const uint32_t height) = 0;

		virtual Ref<Image2D> GetImage() const = 0;

		virtual void Lock() = 0;
		virtual void Unlock() = 0;

		virtual Buffer GetWriteableBuffer() = 0;

		virtual bool Loaded() const = 0;

		virtual const std::filesystem::path& GetPath() const = 0;

		virtual TextureType GetType() const override { return TextureType::Texture2D; }

		static AssetType GetStaticType() { return AssetType::Texture; }
		virtual AssetType GetAssetType() const override { return GetStaticType(); }
	};
	class TextureCube : public Texture
	{
	public:
		static Ref<TextureCube> Create(const TextureSpecification& specification, Buffer imageData = Buffer());

		virtual TextureType GetType() const override { return TextureType::TextureCube; }
		virtual void GenerateMips(bool readonly = false) = 0;
		virtual void GenerateMips(Ref<RenderCommandBuffer> renderCommandBuffer,bool readonly = false) = 0;
		static AssetType GetStaticType() { return AssetType::EnvMap; }
		virtual AssetType GetAssetType() const override { return GetStaticType(); }
	};
```

1. 创建底层Image对象

   ```c++
   ImageSpecification imageSpec;
   imageSpec.Format = m_Specification.Format;
   imageSpec.Width = m_Specification.Width;
   imageSpec.Height = m_Specification.Height;
   imageSpec.Mips = specification.GenerateMips ? GetMipLevelCount() : 1;
   imageSpec.DebugName = specification.DebugName;
   imageSpec.CreateSampler = false;
   m_Image = Image2D::Create(imageSpec);
   ```

2. 从文件中读取数据

   ```c++
   m_ImageData = TextureImporter::ToBufferFromFile(filepath, m_Specification.Format, m_Specification.Width, m_Specification.Height);
   ```

3. 数据写入Image对象（先把数据放在临时缓冲区，再转移到图片），生成MipMap后，转为VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL布局

   ```c++
   void VulkanTexture2D::SetData(Buffer buffer)
   {
   	auto device = VulkanContext::GetCurrentDevice();
   	Ref<VulkanImage2D> image = m_Image.As<VulkanImage2D>();
   	auto& info = image->GetImageInfo();
   
   	VkDeviceSize size = m_ImageData.Size;
   
   	VkMemoryAllocateInfo memAllocInfo{};
   	memAllocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
   
   	VulkanAllocator allocator("Texture2D");
   
   	// Create staging buffer
   	VkBufferCreateInfo bufferCreateInfo{};
   	bufferCreateInfo.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
   	bufferCreateInfo.size = size;
   	bufferCreateInfo.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
   	bufferCreateInfo.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
   	VkBuffer stagingBuffer;
   	VmaAllocation stagingBufferAllocation = allocator.AllocateBuffer(bufferCreateInfo, VMA_MEMORY_USAGE_CPU_TO_GPU, stagingBuffer);
   
   	// Copy data to staging buffer
   	uint8_t* destData = allocator.MapMemory<uint8_t>(stagingBufferAllocation);
   	HZ_CORE_ASSERT(m_ImageData.Data);
   	memcpy(destData, m_ImageData.Data, size);
   	allocator.UnmapMemory(stagingBufferAllocation);
   
   	VkCommandBuffer copyCmd = device->GetCommandBuffer(true);
   
   	// Image memory barriers for the texture image
   
   	// The sub resource range describes the regions of the image that will be transitioned using the memory barriers below
   	VkImageSubresourceRange subresourceRange = {};
   	// Image only contains color data
   	subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   	// Start at first mip level
   	subresourceRange.baseMipLevel = 0;
   	subresourceRange.levelCount = 1;
   	subresourceRange.layerCount = 1;
   
   	// Transition the texture image layout to transfer target, so we can safely copy our buffer data to it.
   	VkImageMemoryBarrier imageMemoryBarrier{};
   	imageMemoryBarrier.sType = VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER;
   	imageMemoryBarrier.srcQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   	imageMemoryBarrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
   	imageMemoryBarrier.image = info.Image;
   	imageMemoryBarrier.subresourceRange = subresourceRange;
   	imageMemoryBarrier.srcAccessMask = 0;
   	imageMemoryBarrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
   	imageMemoryBarrier.oldLayout = VK_IMAGE_LAYOUT_UNDEFINED;
   	imageMemoryBarrier.newLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL;
   
   	// Insert a memory dependency at the proper pipeline stages that will execute the image layout transition
   	// Source pipeline stage is host write/read execution (VK_PIPELINE_STAGE_HOST_BIT)
   	// Destination pipeline stage is copy command execution (VK_PIPELINE_STAGE_TRANSFER_BIT)
   	vkCmdPipelineBarrier(
   		copyCmd,
   		VK_PIPELINE_STAGE_HOST_BIT,
   		VK_PIPELINE_STAGE_TRANSFER_BIT,
   		0,
   		0, nullptr,
   		0, nullptr,
   		1, &imageMemoryBarrier);
   
   	VkBufferImageCopy bufferCopyRegion = {};
   	bufferCopyRegion.imageSubresource.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
   	bufferCopyRegion.imageSubresource.mipLevel = 0;
   	bufferCopyRegion.imageSubresource.baseArrayLayer = 0;
   	bufferCopyRegion.imageSubresource.layerCount = 1;
   	bufferCopyRegion.imageExtent.width = m_Specification.Width;
   	bufferCopyRegion.imageExtent.height = m_Specification.Height;
   	bufferCopyRegion.imageExtent.depth = 1;
   	bufferCopyRegion.bufferOffset = 0;
   
   	// Copy mip levels from staging buffer
   	vkCmdCopyBufferToImage(
   		copyCmd,
   		stagingBuffer,
   		info.Image,
   		VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
   		1,
   		&bufferCopyRegion);
   
   	uint32_t mipCount = m_Specification.GenerateMips ? GetMipLevelCount() : 1;
   	if (mipCount > 1) // Mips to generate
   	{
   		Utils::InsertImageMemoryBarrier(copyCmd, info.Image,
   			VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_TRANSFER_READ_BIT,
   			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
   			VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
   			subresourceRange);
   	}
   	else
   	{
   		Utils::InsertImageMemoryBarrier(copyCmd, info.Image,
   			VK_ACCESS_TRANSFER_READ_BIT, VK_ACCESS_SHADER_READ_BIT,
   			VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, image->GetDescriptorInfoVulkan().imageLayout,
   			VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
   			subresourceRange);
   	}
   
   	device->FlushCommandBuffer(copyCmd);
   
   	// Clean up staging resources
   	allocator.DestroyBuffer(stagingBuffer, stagingBufferAllocation);
   
   	if (m_Specification.GenerateMips && mipCount > 1)
   		GenerateMips();
   }
   ```

   > 对于Cube纹理，就是imageCreateInfo.arrayLayers = 6; // cubeMap本质是一个图片数组，arrayLayers来表示6个面，其他类似

