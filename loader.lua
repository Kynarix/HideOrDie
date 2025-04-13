-- ROBLOX AI HILE ASISTANI - YÜKLEYICI SCRIPT
-- Oyun içinde çalıştırılarak AI Asistanını başlatır
-- Coded by Alpha for Zeta

-- Hata ayıklama modu
local DEBUG = true

-- Debug mesajı
local function debugPrint(...)
    if DEBUG then
        print("[ROBLOX AI LOADER]:", ...)
    end
end

debugPrint("Yükleyici başlatılıyor...")

-- Ana modüllerin varlığını kontrol et
local function checkModules()
    local requiredModules = {
        "main",
        "scanner",
        "analyzer",
        "codegenerator",
        "tester",
        "utils"
    }
    
    local missingModules = {}
    
    for _, moduleName in ipairs(requiredModules) do
        local success = pcall(function()
            local moduleContent = readfile("roblox_ai_assistant/" .. moduleName .. ".lua")
            if not moduleContent or moduleContent == "" then
                table.insert(missingModules, moduleName)
            end
        end)
        
        if not success then
            table.insert(missingModules, moduleName)
        end
    end
    
    return #missingModules == 0, missingModules
end

-- Ana modülleri doğrudan yükle
local function loadModules()
    local modules = {}
    
    -- Ana modülü yükle
    debugPrint("Ana modül yükleniyor...")
    local mainContent = readfile("roblox_ai_assistant/main.lua")
    modules.main = loadstring(mainContent)()
    
    -- Scanner modülünü yükle
    debugPrint("Scanner modülü yükleniyor...")
    local scannerContent = readfile("roblox_ai_assistant/scanner.lua")
    modules.scanner = loadstring(scannerContent)()
    
    -- Diğer modülleri yükle (eğer dosyalar varsa)
    local otherModules = {
        "analyzer",
        "codegenerator",
        "tester",
        "utils"
    }
    
    for _, moduleName in ipairs(otherModules) do
        local success, content = pcall(function()
            return readfile("roblox_ai_assistant/" .. moduleName .. ".lua")
        end)
        
        if success and content and content ~= "" then
            debugPrint(moduleName .. " modülü yükleniyor...")
            modules[moduleName] = loadstring(content)()
        else
            -- Modül bulunamadıysa, boş bir tablo oluştur
            debugPrint(moduleName .. " modülü bulunamadı, boş tablo oluşturuluyor...")
            modules[moduleName] = {}
        end
    end
    
    return modules
end

-- Ana AI sınıfını başlat
local function initializeAI(modules)
    debugPrint("AI Asistanı başlatılıyor...")
    
    -- Main modülünde .new() fonksiyonu varsa kullan
    if modules.main and type(modules.main) == "table" and type(modules.main.new) == "function" then
        local AI = modules.main.new()
        
        -- Modülleri manuel olarak ata
        AI.Scanner = modules.scanner
        AI.Analyzer = modules.analyzer or {}
        AI.CodeGenerator = modules.codegenerator or {}
        AI.Tester = modules.tester or {}
        AI.Utils = modules.utils or {}
        
        -- AI'ı başlat
        if type(AI.Initialize) == "function" then
            AI:Initialize()
            debugPrint("AI Asistanı başlatıldı!")
        else
            debugPrint("UYARI: AI.Initialize fonksiyonu bulunamadı!")
        end
        
        return AI
    else
        error("Main modülünde 'new' fonksiyonu bulunamadı!")
    end
end

-- Ana yükleme işlevi
local function loadAI()
    -- Modülleri kontrol et
    local modulesOK, missingModules = checkModules()
    
    if not modulesOK then
        local missingList = table.concat(missingModules, ", ")
        error("AI Asistanı için gerekli modüller eksik: " .. missingList)
        return nil
    end
    
    -- Modülleri yükle
    local modules = loadModules()
    
    -- AI'ı başlat
    local AI = initializeAI(modules)
    
    -- Global değişkene kaydet
    _G.RobloxAI = AI
    
    return AI
end

-- Yüklemeyi çalıştır
local success, result = pcall(loadAI)

if not success then
    warn("[ROBLOX AI HATA] AI Asistanı yüklenemedi: " .. tostring(result))
    
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
        ErrorMessage.Text = "AI Asistanı yüklenemedi:\n\n" .. tostring(result)
        ErrorMessage.TextWrapped = true
        ErrorMessage.TextXAlignment = Enum.TextXAlignment.Left
        ErrorMessage.TextYAlignment = Enum.TextYAlignment.Top
        ErrorMessage.Parent = ErrorBox
        
        -- UI'ı göster
        ErrorFrame.Parent = game:GetService("CoreGui")
    end)
else
    debugPrint("AI Asistanı başarıyla yüklendi!")
end

return success and result or nil 