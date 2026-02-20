describe("Ace3 Library Tests", function()
  it("should load LibStub and AceAddon-3.0 successfully", function()
    -- LibStub is globally registered by WoW convention (and mocked in setup)
    assert.is_not_nil(LibStub)

    local AceAddon = LibStub("AceAddon-3.0", true)
    assert.is_not_nil(AceAddon)

    -- Test that we can create a simple addon
    local myAddon = AceAddon:NewAddon("TestAddon")
    assert.is_not_nil(myAddon)
    assert.are.equal("TestAddon", myAddon:GetName())
  end)

  it("should load newly added Ace3 libraries successfully", function()
    -- Check that all newly added libraries are registered via LibStub
    local AceEvent = LibStub("AceEvent-3.0", true)
    assert.is_not_nil(AceEvent)

    local AceDB = LibStub("AceDB-3.0", true)
    assert.is_not_nil(AceDB)

    local AceHook = LibStub("AceHook-3.0", true)
    assert.is_not_nil(AceHook)

    local AceConsole = LibStub("AceConsole-3.0", true)
    assert.is_not_nil(AceConsole)

    local AceDBOptions = LibStub("AceDBOptions-3.0", true)
    assert.is_not_nil(AceDBOptions)

    local AceConfig = LibStub("AceConfig-3.0", true)
    assert.is_not_nil(AceConfig)

    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    assert.is_not_nil(AceConfigRegistry)

    local AceConfigCmd = LibStub("AceConfigCmd-3.0", true)
    assert.is_not_nil(AceConfigCmd)

    -- We are skipping AceGUI-3.0 and AceConfigDialog-3.0
    local AceGUI = LibStub("AceGUI-3.0", true)
    assert.is_nil(AceGUI)

    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    assert.is_nil(AceConfigDialog)
  end)
end)
