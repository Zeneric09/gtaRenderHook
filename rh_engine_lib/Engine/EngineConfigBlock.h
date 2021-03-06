//
// Created by peter on 13.06.2020.
//
#pragma once
#include "../ConfigUtils/ConfigBlock.h"

namespace rh::engine
{

class EngineConfigBlock : public ConfigBlock
{
  public:
    static EngineConfigBlock It;

  public:
    EngineConfigBlock() noexcept;

    void Reset();

    void        Deserialize( Serializable *serializable ) override;
    void        Serialize( Serializable *serializable ) override;
    std::string Name() override { return "Engine"; }

  public:
    /// Properties
    bool     IsWindowed{};
    uint32_t SharedMemorySizeMB = 32;
    uint32_t RenderingAPI_id    = 0;
    uint32_t RendererWidth      = 1920;
    uint32_t RendererHeight     = 1080;
};
} // namespace rh::engine