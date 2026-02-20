describe("AceAddon-3.0 Test", function()
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
end)
