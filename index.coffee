_ = require("underscore")

module.exports = RedisSharelatex =
	createClient: (opts = {port: 6379, host: "localhost"})->
		if !opts.retry_max_delay?
			opts.retry_max_delay = 5000 # ms
		
		if opts.password?
			opts.auth_pass = opts.password
			delete opts.password
		if opts.endpoints?
			standardOpts = _.clone(opts)
			delete standardOpts.endpoints
			delete standardOpts.masterName
			client = require("redis-sentinel").createClient opts.endpoints, opts.masterName, standardOpts
		else
			standardOpts = _.clone(opts)
			delete standardOpts.port
			delete standardOpts.host
			client = require("redis").createClient opts.port, opts.host, standardOpts
		return client
		
	createRobustSubscriptionClient: (opts, heartbeatOpts = {}) ->
		sub = RedisSharelatex.createClient(opts)
		pub = RedisSharelatex.createClient(opts)
		
		heartbeatInterval = heartbeatOpts.heartbeat_interval or 1000 #ms
		reconnectAfter = heartbeatOpts.reconnect_after or 5000 #ms
		
		id = require("crypto").createHash("md5").update(Math.random().toString()).digest("hex")
		heartbeatChannel = "heartbeat-#{id}"
		lastHeartbeat = Date.now()
		
		sub.subscribe heartbeatChannel, (error) ->
			if error?
				console.error "ERROR: failed to subscribe to #{heartbeatChannel} channel", error
		sub.on "message", (channel, message) ->
			if channel == heartbeatChannel
				lastHeartbeat = Date.now()
		
		reconnectIfInactive = () ->
			timeSinceLastHeartBeat = Date.now() - lastHeartbeat
			if timeSinceLastHeartBeat > reconnectAfter
				console.warn "No heartbeat for #{timeSinceLastHeartBeat}ms, reconnecting"
				sub.connection_gone("no heartbeat for #{timeSinceLastHeartBeat}ms")
		
		setInterval () ->
			pub.publish heartbeatChannel, "PING"
			reconnectIfInactive()
		, heartbeatInterval
		
		return sub
			
		


