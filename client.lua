local freemodeModels<const> = {
  [`mp_m_freemode_01`] = 'mp_m_freemode_01',
  [`mp_f_freemode_01`] = 'mp_f_freemode_01'
}

---Is the model either of the freemode models?
  ---@param modelHash string|integer
local function isFreemodeModel(modelHash)
  return freemodeModels[modelHash] ~= nil
end

---Gets head blend data
  ---@param ped integer
  ---@return { shapeFirst: integer, shapeSecond: integer, shapeThird: integer, skinFirst: integer, skinSecond: integer, skinThird: integer, shapeMix: number, skinMix: number, thirdMix: number }
local function getHeadBlendData(ped)
  -- GTA returns some dumb struct with pointers
  -- This is a goofy way to get the data in Lua.
  -- Alternatively, you would need a C# or JS
  -- script to get the data. However, this is
  -- a lot less work.
  -- People discussed this here:
  -- https://forum.cfx.re/t/head-blend-data/212575/24
  local tbl<const> = {
    Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueIntInitialized(0),
      Citizen.PointerValueFloatInitialized(0),
      Citizen.PointerValueFloatInitialized(0),
      Citizen.PointerValueFloatInitialized(0)
    )
  }

  return {
    shapeFirst = tbl[1],
    shapeSecond = tbl[2],
    shapeThird = tbl[3],
    skinFirst = tbl[4],
    skinSecond = tbl[5],
    skinThird = tbl[6],
    shapeMix = tbl[7],
    skinMix = tbl[8],
    thirdMix = tbl[9]
  }
end

local savedBlendData, savedFaceFeatures = {}, {}
local isHeadShrunken = false

local lastMaskDrawable, lastMaskTexture = -1, -1
local function loop()
  local ped<const> = PlayerPedId()
  if not DoesEntityExist(ped) then return end

  local currentMaskDrawable<const> = GetPedDrawableVariation(ped, 1)
  local currentMaskTexture<const>  = GetPedTextureVariation(ped, 1)
  if currentMaskDrawable == lastMaskDrawable and currentMaskTexture == lastMaskTexture then return end
  lastMaskDrawable = currentMaskDrawable
  lastMaskTexture = currentMaskTexture
  
  local maskHash<const> = GetHashNameForComponent(ped, 1, currentMaskDrawable, currentMaskTexture)
  if currentMaskDrawable > 0 and maskHash == 0 then return end

  local pedModelHash<const> = GetEntityModel(ped)
  if not isFreemodeModel(pedModelHash) then return end

  if not DoesShopPedApparelHaveRestrictionTag(maskHash, `SHRINK_HEAD`, 0) then
    if isHeadShrunken then
      CreateThread(function()
        SetPedHeadBlendData(ped,
          savedBlendData.shapeFirst, savedBlendData.shapeSecond, savedBlendData.shapeThird,
          savedBlendData.skinFirst, savedBlendData.skinSecond, savedBlendData.skinThird,
          savedBlendData.shapeMix, savedBlendData.skinMix, savedBlendData.thirdMix,
          false
        )
        repeat Wait(0) until HasPedHeadBlendFinished(ped)
        for i = 0, 19 do
          SetPedFaceFeature(ped, i, savedFaceFeatures[i])
        end
        isHeadShrunken = false
      end)
    end
    return
  end

  local headBlendData<const> = getHeadBlendData(ped)

  savedBlendData = headBlendData
  isHeadShrunken = true

  SetPedHeadBlendData(ped,
    freemodeModels[pedModelHash] == 'mp_m_freemode_01' and 0 or 21, 0, 0, -- Reset shape
    headBlendData.skinFirst, headBlendData.skinSecond, headBlendData.skinThird, -- Keep skin
    0.0, headBlendData.skinMix, 0.0, -- Reset all but skin mix
    false -- isParent (Unk effect)
  )

  for i = 0, 19 do
    savedFaceFeatures[i] = GetPedFaceFeature(ped, i)
    SetPedFaceFeature(ped, i, 0.0)
  end
end

CreateThread(function()
  while true do
    loop() -- This is a function, because it's easier to return out of
    Wait(0)
  end
end)
