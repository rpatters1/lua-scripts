--[[
$module MusicXML

A collection of helpful routines for manipulating MusicXML as nested Lua tables.
Require tinyxml2, which is available in RGP Lua 0.67 or higher.

There routines support score-partwise order only.
]]

local musicxml = {}

local partwise = "score-partwise"

local musicxml_version = 4

local header_element =
{
    "work",
    "movement-number",
    "movement-title",
    "identification",
    "defaults",
    "credit",
    "part-list"
}

local element_orders =
{
    work =
    {
        "work-numbers",
        "work-title",
        "opus"
    },
    identification =
    {
        "creator",
        "rights",
        "encoding",
        "source",
        "relation",
        "miscellaneous"        
    },
    defaults =
    {
        "scaling",
        "concert-score",
        "page-layout",
        "system-layout",
        "staff-layout",
        "appearance",
        "music-font",
        "word-font",
        "lyric-font",
        "lyric-language"
    },
    credit =
    {
        "credit-type",
        "link",
        "credit-image",
        "link",
        "bookmark",
        "credit-words",
        "credit-symbol"
    },
    ["part-list"] =
    {
        "score-part",
        "part-group"
    },
    measure =
    {
        "attributes",
        "direction",
        "harmony",
        "note",
        "backup",
        "forward",
        "sound"
    }
}

local function is_header_element(s)
    for _, v in ipairs(header_element) do
        if s == v then return true end
    end
    return false
end

local insert_in_order -- for recursive call
insert_in_order = function(t, element, name)
    local order = element_orders[name]
    if not order then
        table2xml(t, element, { boolyesno = true, name = name })
    else
        subt = t[name]
        if subt then
            sub_element = element:GetDocument():NewElement(name)
            for _, v in ipairs(order) do
                if subt[v] then
                    insert_in_order(subt, sub_element, v)
                end
            end
            element:InsertEndChild(sub_element)
        end
    end
end

--[[
% table2musicxml

Converts a table to musicxml. It should contain the header and part information.
This function inserts the root element "score-partwise" and other required elements.

@ input (table) a hierarchical table containing music data
: (XMLDocument) an XML document containing the musicxml.
]]

function musicxml.table2musicxml(t)
    if type(t) ~= "table" then
        error("expected input type of table", 2)
    end
    if type(t["part-list"]) ~= "table" or type(t["part"]) ~= "table" then
        error("part-list or part element(s) are missing", 2)
    end
    for k, _ in pairs(t) do
        if k ~= "part" and k ~= "_attr" and not is_header_element(k) then
            error("invalid header element '"..tostring(k).."'", 2)
        end
    end
    local xml = tinyxml2.XMLDocument()
    xml:InsertEndChild(xml:NewDeclaration("xml version=\"1.0\" encoding=\"UTF-8\""))
    xml:InsertEndChild(xml:NewUnknown("DOCTYPE " .. partwise .. " PUBLIC \"-//Recordare//DTD MusicXML 4.0 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\""))
    local root = xml:NewElement(partwise)
    root:SetIntAttribute("version", musicxml_version)
    for k, v in ipairs(header_element) do
        if t[v] then
            insert_in_order(t, root, v)
        end
    end
    root:InsertEndChild(xml:NewComment("========================================================="))
    insert_in_order(t, root, "part")
    -- todo: manage each part element
    --[[
    for _, v in ipairs(t["part"]) do
        -- ToDo: part order dependence
        element = xml:NewElement("part")
        table2xml(v, element, { boolyesno = true })
        root:InsertEndChild(element)
    end
    ]]
    root:InsertEndChild(xml:NewComment("========================================================="))
    xml:InsertEndChild(root)
    return xml
end

return musicxml
