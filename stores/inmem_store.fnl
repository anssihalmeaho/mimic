
ns inmem_store

get-store = proc()
	import stdpp
	import stdvar

	store-ref = call(stdvar.new map())

	# method for writing action log
	write = proc(action-list)
		apply-actions = func(actions result)
			if(empty(actions)
				result
				call(func()
					action = head(actions)
					next-result = case(head(action)
						'start' head(rest(action))

						'put'
						call(func()
							key value = rest(action):
							put(result key value)
						end)

						'del' del(result head(rest(action)))
					)
					call(apply-actions rest(actions) next-result)
				end)
			)
		end

		mapvalue = call(stdvar.value store-ref)
		newvalue = call(apply-actions action-list mapvalue)
		_ = call(stdvar.set store-ref newvalue)
		list(true '')
	end

	# method for reading whole map
	read-all = proc()
		list(true '' call(stdvar.value store-ref))
	end

	# open method (dummy)
	open = proc()
		list(true '')
	end

	# close method (dummy)
	close = proc()
		true
	end

	# store object
	map(
		'open'     open
		'write'    write
		'read-all' read-all
		'close'    close
	)
end

endns

