local GUI = require("GUI")
local system = require("System")
local component = require("component")
local event = require("event")
local modem = component.modem

local history =  {}
local currentIndex = 0

local DNS_PORT = 53
local ServerPort = 80

-- local waitingDelay = 0.5

local dnsServerAddress = "f968f015-a44e-440e-b4bd-70bb97f94b9e"

-- Create the main window
local workspace, window, menu = system.addWindow(GUI.filledWindow(1, 1, 100, 30, 0x2D2D2D))

-- Create the address bar input field (top of the window)
local addressBar = window:addChild(GUI.input(3, 2, 80, 3, 0xFFFFFF, 0x555555, 0x888888, 0x262626, 0xFFFFFF, "", "Enter URL"))

-- Create navigation buttons
local goButton = window:addChild(GUI.button(85, 2, 10, 3, 0xAAAAAA, 0x2D2D2D, 0xFFFFFF, 0x555555, "Go"))
local backButton = window:addChild(GUI.button(3, 6, 10, 3, 0xAAAAAA, 0x2D2D2D, 0xFFFFFF, 0x555555, "Back"))
local forwardButton = window:addChild(GUI.button(14, 6, 10, 3, 0xAAAAAA, 0x2D2D2D, 0xFFFFFF, 0x555555, "Forward"))

-- Create a display area for the web content
local displayArea = window:addChild(GUI.panel(3, 10, window.width - 6, window.height - 12, 0xFFFFFF))

-- A text box to simulate web content, that is scrollable
local webContent = window:addChild(GUI.textBox(3, 10, displayArea.width, displayArea.height, 0xFFFFFF, 0x000000, {}, 1, 0, 0))

local function resolveDomain(domain)
    modem.open(DNS_PORT)
    
    -- Send the DNS request
    modem.send(dnsServerAddress, DNS_PORT, domain)
    
    -- Create a handler to listen for the "modem_message" event
    local signalType, from, port, _, _, response = event.pull()

    if signalType == "modem_message" then
        if response == "Domain Not Found" then
            GUI.alert("Domain not found.")
            return nil
        elseif not response then
            GUI.alert("No response from DNS server.")
            return nil
        else
            return response  -- Return the address if successful
        end
    end
end

local function renderHTML(htmlcontent)
    local lines = {}
    
    htmlcontent = htmlcontent:gsub("<h1>(.-)</h1>", function(text)
        return "\n# " .. text .. "\n" 
    end)

    htmlcontent = htmlcontent:gsub("<p>(.-)</p>", function(text)
        return "\n" .. text .. "\n"
    end)

    htmlcontent = htmlcontent:gsub("<b>(.-)</b>", function(text)
        return "**" .. text .. "**"
    end)

    htmlcontent = htmlcontent:gsub("<a href=\"(.-)\">(.-)</a>", function(link, text)
        return "[[" .. text .. "]](" .. link .. ")"
    end)
    
    htmlcontent = htmlcontent:gsub("<br>", "\n")
    
    bean = htmlcontent
    
    for line in bean:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    return lines
end

-- Function to handle navigation (this is where you'd load web content, for example)
local function loadPage(url)
    webContent.lines = {}
    
    url = url:gsub("https?://", "")

    local strippedURL = url:match("([^/]+)")

    -- Extract the domain and the path (everything after the first "/")
    local domain = strippedURL:match("([^/]+)")
    local path = url:match("https?://[^/]+(/.+)") or url:match("[^/]+(/.+)") or "/home"

    local address = resolveDomain(domain)

    if address then
        modem.open(ServerPort)

        modem.send(address, ServerPort, "GET " .. path)

        local signalType, from, port, _, _, response = event.pull()

        if signalType == "modem_message" then
            if response == "Domain Not Found" then
                GUI.alert("Domain not found.")
                return nil
            elseif not response then
                GUI.alert("No response from DNS server.")
                return nil
            else
                webContent.lines = renderHTML(response)
                webContent:draw()
            end
        end
    else
        webContent.lines = {"404 Website not found"}
        webContent:draw()
    end
end

-- Add an event handler for the "Go" button
goButton.onTouch = function()
    local url = addressBar.text
    if url and url ~= "" then
        loadPage(url)  -- Simulate loading the web content
    else
        GUI.alert("Please enter a valid URL")
    end
end

-- Back and forward buttons (placeholders for actual functionality)
backButton.onTouch = function()
    webContent.lines = {"Back button pressed!"}
    webContent:draw()
end

forwardButton.onTouch = function()
    webContent.lines = {"Forward button pressed"}
    webContent:draw()
end

-- Draw the initial workspace
workspace:draw()
