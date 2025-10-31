ConfigHandler = {}

function ConfigHandler.loadConfig(data)
    for aliasToCall, config in pairs(data) do
        local nameToCall = LDTK_CONFIG_ALIASES[aliasToCall] or aliasToCall

        local classToCall = _G[nameToCall]

        if classToCall and classToCall.load then
            classToCall.load(config)
        else
            print("Config Handler <" .. nameToCall .. "> is missing or has no :load(config) method.")
        end
    end
end
