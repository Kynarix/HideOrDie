-- ROBLOX AI HILE ASISTANI - ANA BAŞLATICI
-- Tüm modülleri ve ana sistemi başlatan script
-- Coded by Alpha for Zeta

-- Hata ayıklama fonksiyonu 
local function debugPrint(...)
    print("[ROBLOX AI DEBUG]:", ...)
end

debugPrint("AI Asistanı yüklenmeye başlıyor...")

-- Ana modülleri doğrudan içe aktar
local success, result = pcall(function()
    -- Ana klasörü tespit etmeye çalış
    local scriptPath = debug.getinfo(1, "S").source:sub(2)
    local scriptDir = scriptPath:match("(.*/)") or ""
    debugPrint("Script klasörü: " .. scriptDir)
    
    -- ModuleScript olarak çalıştırılıp çalıştırılmadığını kontrol et
    local isModuleScript = getfenv(0).script and getfenv(0).script:IsA("ModuleScript")
    debugPrint("ModuleScript mi? " .. tostring(isModuleScript))
    
    -- Ana modül yolu
    local mainPath = isModuleScript and script or scriptDir .. "main"
    debugPrint("Ana modül yolu: " .. tostring(mainPath))
    
    -- Main modülünü yükle
    local mainModule
    
    if isModuleScript then
        -- ModuleScript çalıştırılıyorsa, script.Parent'dan yükle
        mainModule = require(script.Parent.main)
    else
        -- Değilse, loadstring ile yükle
        local mainScript = readfile(scriptDir .. "main.lua")
        mainModule = loadstring(mainScript)()
    end
    
    debugPrint("Ana modül yüklendi")
    
    -- Diğer modülleri tanımla (aslında bunlar main.lua içinden yüklenecek)
    local modules = {
        "Scanner",
        "Analyzer",
        "CodeGenerator",
        "Tester",
        "Utils"
    }
    
    -- Ana modülü başlat
    local AI = mainModule.new()
    debugPrint("AI Asistanı başlatıldı!")
    
    -- Referansı global değişkene kaydet (kolay erişim için)
    _G.RobloxAI = AI
    
    return AI
end)

if not success then
    warn("[ROBLOX AI HATA] AI Asistanı başlatılamadı: " .. tostring(result))
    
    -- Acil durum UI'ı oluştur - en azından bir hata mesajı göster
    pcall(function()
        local ErrorFrame = Instance.new("ScreenGui")
        ErrorFrame.Name = "RobloxAI_Error"
        
        local ErrorBox = Instance.new("Frame")
        ErrorBox.Size = UDim2.new(0, 300, 0, 150)
        ErrorBox.Position = UDim2.new(0.5, -150, 0.5, -75)
        ErrorBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        ErrorBox.BorderSizePixel = 0
        ErrorBox.Parent = ErrorFrame
        
        local ErrorTitle = Instance.new("TextLabel")
        ErrorTitle.Size = UDim2.new(1, 0, 0, 30)
        ErrorTitle.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
        ErrorTitle.BorderSizePixel = 0
        ErrorTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
        ErrorTitle.TextSize = 16
        ErrorTitle.Font = Enum.Font.SourceSansBold
        ErrorTitle.Text = "Roblox AI Hile Asistanı - HATA"
        ErrorTitle.Parent = ErrorBox
        
        local ErrorMessage = Instance.new("TextLabel")
        ErrorMessage.Size = UDim2.new(1, -20, 1, -40)
        ErrorMessage.Position = UDim2.new(0, 10, 0, 35)
        ErrorMessage.BackgroundTransparency = 1
        ErrorMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
        ErrorMessage.TextSize = 14
        ErrorMessage.Font = Enum.Font.SourceSans
        ErrorMessage.Text = "AI Asistanı başlatılamadı:\n\n" .. tostring(result)
        ErrorMessage.TextWrapped = true
        ErrorMessage.TextXAlignment = Enum.TextXAlignment.Left
        ErrorMessage.TextYAlignment = Enum.TextYAlignment.Top
        ErrorMessage.Parent = ErrorBox
        
        -- UI'ı göster
        ErrorFrame.Parent = game:GetService("CoreGui")
    end)
else
    -- AI başarıyla başlatıldı, global erişim için _G'ye ekle
    _G.RobloxAI = result
end

return success and result or nil 