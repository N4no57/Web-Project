-- DNSServer.lua
local component = require("component")
local event = require("event")
local modem = component.modem

-- Ports for DNS queries and dynamic updates
local DNS_PORT = 53
local DNS_UPDATE_PORT = 54

-- Table to store domain-to-address mappings
local dnsTable = {}

-- Open the DNS ports for listening
modem.open(DNS_PORT)
modem.open(DNS_UPDATE_PORT)

print("DNS Server is running...")

while true do
    local _, _,  from, port, _, message = event.pull("modem_message")
    
    if port == DNS_PORT then
        -- Handle DNS query
        print("Received DNS request for: " .. message)
        local address = dnsTable[message]
        if address then
            modem.send(from, port, address)
            print("sending address: " .. address .. "to computer:" .. from)
        else
            modem.send(from, port, "Domain Not Found")
            print("address not found")
        end

    elseif port == DNS_UPDATE_PORT then
        -- Handle dynamic DNS updates (format: "domain|address")
        local domain, address = message:match("([^|]+)|([^|]+)")
        if domain and address then
            dnsTable[domain] = address
            print("Updated DNS record: " .. domain .. " -> " .. address)
            modem.send(from, port, "DNS Update Successful")
        else
            modem.send(from, port, "Invalid Update Format")
        end
    end
end