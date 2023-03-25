
ns evenz

# factory procedure for creating new event service object
new-evenz = proc()
	import stdvar
	import stdfu

	import stdpr
	deb-print = call(stdpr.get-pr false)

	ch = chan()
	subs = call(stdvar.new list())
	binding-id = call(stdvar.new 10)

	# generates next binding id
	next-bind-id = proc()
		_ _ next-cnt = call(stdvar.change binding-id func(cnt) plus(cnt 1) end):
		str(next-cnt)
	end

	# procedure (private method) for notifying listeners
	notify-all-listeners = proc(val)
		subs-handler = proc(item _)
			matcher handler itemid = item:
			is-match = call(matcher val)
			_ = call(deb-print 'listener -> ' itemid)
			if(is-match call(handler val) 'no match')
		end

		call(stdfu.ploop subs-handler call(stdvar.value subs) 'none')
	end

	# receiving fiber which triggers calls to all listeners
	_ = spawn(call(proc()
		_ = call(notify-all-listeners recv(ch))
		while(true 'none')
	end))

	# returns new listener object
	new-listener = proc(matcher handler)
		stop-ch = chan()
		bind-id = call(next-bind-id)

		remove-by-id = func(prev-subs)
			call(stdfu.filter prev-subs func(item) _ _ itemid = item: not(eq(itemid bind-id)) end)
		end

		# method starting event listening
		listen = proc()
			_ = call(stdvar.change subs func(v) append(v list(matcher handler bind-id)) end)
			explanation = recv(stop-ch)
			_ = call(deb-print 'stop listener: ' bind-id ': ' explanation)
			_ = call(stdvar.change subs remove-by-id)
			explanation
		end

		# method for stopping listening
		cancel = proc()
			send(stop-ch 'listening cancelled')
		end

		map(
			'listen' listen
			'cancel' cancel
		)
	end

	# event publishing method
	publish = proc(val)
		send(ch val)
	end

	# event service object
	map(
		'new-listener' new-listener
		'publish'      publish
	)
end

endns

