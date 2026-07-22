local _, API = ...

API = API or {}
API.locales = API.locales or {}

function API.RegisterLocale(locale, values)
    if type(locale) ~= "string" or type(values) ~= "table" then return end
    API.locales[locale] = API.locales[locale] or {}
    for key, value in pairs(values) do
        API.locales[locale][key] = value
    end
end

function API.GetLocaleText(key)
    if key == nil then return "" end
    key = tostring(key)
    local configuredLocale = CFG and CFG.addonLocale or "AUTO"
    local locale = configuredLocale ~= "AUTO" and configuredLocale
        or (GetLocale and GetLocale() or "enUS")
    local localized = API.locales[locale]
    local english = API.locales.enUS
    return localized and localized[key] or english and english[key] or key
end

S2K_ADDON_LOCALE_OPTIONS = {
    { key = "AUTO", label = "Automatic" },
    { key = "enUS", label = "English" },
    { key = "huHU", label = "Hungarian" },
}

function API.FormatLocaleText(key, ...)
    local text = API.GetLocaleText(key)
    if select("#", ...) == 0 then return text end
    local ok, formatted = pcall(string.format, text, ...)
    return ok and formatted or text
end

function S2K_L(key)
    return API.GetLocaleText(key)
end

function S2K_LF(key, ...)
    return API.FormatLocaleText(key, ...)
end
