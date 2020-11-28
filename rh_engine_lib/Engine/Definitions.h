#pragma once

#include <cstdint>
namespace rh::engine
{

enum class RenderingAPI : uint32_t
{
    DX11,
    Vulkan
};

}; // namespace rh::engine
