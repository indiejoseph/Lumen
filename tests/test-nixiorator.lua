---
-- A task that interfaces with nixio. Supports UDP, TCP and async
-- file I/O.
-- Should run as root or sudo, for reading /dev/input/mice

--look for packages one folder up.
package.path = package.path .. ";;;../?.lua"

require "strict"

local sched = require "sched"
local catalog = require "catalog"
local nixiorator = require "tasks/nixiorator"
local nixio = nixiorator.nixio

-- Print out data arriving on a fd
local fdrecv = assert(nixio.open('/dev/input/mice', nixio.open_flags('rdonly', 'sync')), 'run as root!')
nixiorator.register_client(fdrecv, 10)
sched.sigrun(
	{emitter=nixiorator.task, events={fdrecv}}, 
	function(_, _, data) print("!F", data:byte(1, #data)) end
)

-- Print out data arriving on a udp socket
local udprecv = assert(nixio.bind("127.0.0.1", 8888, 'inet', 'dgram'))
nixiorator.register_client(udprecv, 1500)
sched.sigrun(
	{emitter=nixiorator.task, events={udprecv}}, 
	function(_, _, ...) print("!U", ...) end
)

-- Accept tcp connections and print out arriving data
sched.run(function()
	local tcprecv = assert(nixio.bind("127.0.0.1", 8888, 'inet', 'stream'))
	nixiorator.register_server(tcprecv, 'line')
	catalog.register("accepter")
	local waitd={emitter=nixiorator.task, events={tcprecv}}
	while true do
		local _,skt, msg, inskt  = sched.wait(waitd)
		print ("#", os.time(), skt, msg, inskt )
		if msg=='accepted' then
			sched.sigrun(
				{emitter=nixiorator.task, events={inskt}},
				function(_, _, data, err)
					print("!T", data, err or '')
					if not data then sched.kill() end
				end
			)
		end
	end
end)

-- Send data over a tcp socket
sched.run(function()
	catalog.waitfor('accepter')
	local tcpsend = assert(nixio.bind("127.0.0.1", 0, 'inet', 'stream'))
	tcpsend:connect("127.0.0.1",8888)
	while true do
		local m="ping! "..os.time()
		print("tcp sending",m)
		tcpsend:writeall(m.."\n")
		sched.sleep(3)
	end
end)

-- Send data over an udp socket
sched.run(function()
	local udpsend = assert(nixio.bind("127.0.0.1", 0, 'inet', 'dgram'))
	udpsend:connect("127.0.0.1",8888)
	while true do
		local m="ping! "..os.time()
		print("udp sending",m)
		udpsend:send(m)
		sched.sleep(2)
	end
end)


sched.go()