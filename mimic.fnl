
ns mimic

new-mappy = func(initial)
	create-mappy = func(mapval log)
		# method to mimic put -operation for mappy
		putv = func(key value)
			call(create-mappy
				put(mapval key value)
				append(log list('put' key value))
			)
		end

		# method to mimic del -operation for mappy
		delv = func(key)
			call(create-mappy
				del(mapval key)
				append(log list('del' key))
			)
		end

		# method to mimic dell -operation for mappy
		dellv = func(key)
			key-found newmap = dell(mapval key):
			nmappy = if(key-found
				call(create-mappy
					newmap
					append(log list('del' key))
				)
				call(create-mappy
					mapval
					log
				)
			)
			list(key-found nmappy)
		end

		# mappy object
		map(
			# reading
			'get'     func(key) get(mapval key) end
			'getl'    func(key) getl(mapval key) end
			'in'      func(key) in(mapval key) end
			'keys'    func() keys(mapval) end
			'vals'    func() vals(mapval) end
			'keyvals' func() keyvals(mapval) end
			'empty'   func() empty(mapval) end
			'len'     func() len(mapval) end

			# new mappy creations
			'put'   putv
			'del'   delv
			'dell'  dellv

			# methods for getting log and latest map
			'log'  func() log end
			'map'  func() mapval end
		)
	end

	call(create-mappy initial list(list('start' initial)))
end

# create new base
init-base = proc(storer)
	import evenz
	import stdvar

	# read initial value from storage
	map-value = call(proc()
		open-ok open-err = call(get(storer 'open')):
		_ = if(open-ok 'ok' error(sprintf('storage open failed: %s' open-err)))
		ok err initial-value = call(get(storer 'read-all')):
		_ = if(ok 'ok' error(sprintf('reading from storage failed: %s' err)))
		initial-value
	end)

	is-open-ref = call(stdvar.new true)

	es = call(evenz.new-evenz)
	publish = get(es 'publish')
	new-es-listener = get(es 'new-listener')

	# new listener
	new-listener = proc(matcher eventhandler)
		call(new-es-listener matcher eventhandler)
	end

	server-chan = chan()

	# server fiber
	_ = spawn(call(
		proc(my-mappy)
			proce replych = recv(server-chan):
			newmappy retval = call(proce my-mappy):
			_ = send(replych retval)
			while(true newmappy 'whatever')
		end
		call(new-mappy map-value)
	))

	# get latest mappy value
	get-mappy = proc()
		getter = proc(mval) list(mval mval) end

		call(proc()
			replych = chan()
			_ = send(server-chan list(getter replych))
			recv(replych)
		end)
	end

	# closing
	close = proc()
		closer = proc(mval)
			_ = call(get(storer 'close'))
			list(mval 'closed')
		end

		replych = chan()
		_ = send(server-chan list(closer replych))
		_ = recv(replych)
		# TODO: in theory there is small time window in which some
		# method may get to running...
		_ = call(stdvar.set is-open-ref false)
		_ = call(publish list('close'))
		true
	end

	# write new mappy value
	commit = proc(with-mappy)
		has-same-origin = func(log orig-mappy)
			orig-map = call(get(orig-mappy 'map'))
			if(empty(log)
				false
				call(func()
					entry = head(log)
					action = head(entry)
					if(eq(action 'start')
						call(func()
							base-map = head(rest(entry))
							eq(base-map orig-map)
						end)

						false
					)
				end)
			)
		end

		committer = proc(mval)
			new-mapv = call(get(with-mappy 'map'))
			change-log = call(get(with-mappy 'log'))

			if(call(has-same-origin change-log mval)
				call(proc()
					write-ok write-err = call(get(storer 'write') change-log):
					_ = call(publish list('commit' change-log))
					if(write-ok
						call(proc()
							# lets make new mappy so that its log is initialized
							newmappy = call(new-mappy new-mapv)
							list(newmappy list(true '' newmappy))
						end)

						list(mval list(false write-err mval))
					)
				end)

				list(mval list(false 'version conflict' mval))
			)
		end

		replych = chan()
		_ = send(server-chan list(committer replych))
		recv(replych)
	end

	# method wrapper for handling closed check
	closed-wrapper = proc(method)
		proc()
			is-open = call(stdvar.value is-open-ref)
			_ = if(is-open 'ok' error('closed'))
			call(method argslist():)
		end
	end

	# base -object
	map(
		'get-mappy'    call(closed-wrapper get-mappy)
		'commit'       call(closed-wrapper commit)
		'new-listener' call(closed-wrapper new-listener)
		'close'        close
	)
end

endns

