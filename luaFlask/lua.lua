-- flaskServer.lua
local component = require("component")
local event = require("event")
local modem = component.modem

local flaskServer = {
    routes = {},
    middleware = {},
    port = 80,  -- Default HTTP port
    dnsServerAddress = "dns_server_address_here",  -- DNS server to register with
    dnsUpdatePort = 54,
    domain = nil,
}

-- Register a route (URL path) and associate it with a handler function
function flaskServer.route(path, handler)
    flaskServer.routes[path] = handler
end

-- Register the server with a DNS server
function flaskServer.registerDNS(domain)
    flaskServer.domain = domain
    local myAddress = modem.address
    local registrationMessage = domain .. "|" .. myAddress

    -- Send the registration message to the DNS server
    modem.open(flaskServer.dnsUpdatePort)
    modem.send(flaskServer.dnsServerAddress, flaskServer.dnsUpdatePort, registrationMessage)

    -- Wait for DNS server response
    local _, _, _, _, _, message = event.pull("modem_message")
    if message == "DNS Update Successful" then
        print("Domain registered successfully with DNS server.")
    else
        error("Failed to register domain: " .. message)
    end
end

-- Register middleware to process requests before they reach the handler
function flaskServer.use(middlewareFunction)
    table.insert(flaskServer.middleware, middlewareFunction)
end

-- Start the server
function flaskServer.run(domain, port)
    if port then
        flaskServer.port = port
    end

    -- Register the server with DNS
    flaskServer.registerDNS(domain)

    -- Open the server port
    modem.open(flaskServer.port)
    print("Server running on port " .. flaskServer.port)
    print("Domain: " .. domain)

    -- Main event loop
    while true do
        local _, _, from, port, _, message = event.pull("modem_message")
        if port == flaskServer.port then
            -- Parse method and path from the message (e.g., "GET /home")
            local method, fullPath = message:match("^(%S+)%s(%S+)")
            print(fullpath)
            if method and fullPath then
                -- Separate path and query parameters
                local path, queryString = fullPath:match("([^?]+)%??(.*)")
                print(path)
                local params = {}
                for key, value in queryString:gmatch("([^&=]+)=([^&=]+)") do
                    params[key] = value
                end

                -- Apply middleware
                local continue = true
                for _, middlewareFunction in ipairs(flaskServer.middleware) do
                    continue = middlewareFunction(params, method)
                    if not continue then break end
                end

                -- Route to the correct handler
                if continue and flaskServer.routes[path] then
                    local response = flaskServer.routes[path](params, method)
                    modem.send(from, port, response)
                else
                    modem.send(from, port, "404 Not Found")
                end
            else
                modem.send(from, port, "400 Bad Request")
            end
        end
    end
end

return flaskServer