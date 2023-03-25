
ns logfilestore

get-store = proc(filename)
	import stdfiles
	import stdser
	import stdbytes

	open-file = proc(fname)
		fh = call(stdfiles.open fname plus(stdfiles.a stdfiles.r))
		if(eq(type(fh) 'string')
			call(proc()
				file = call(stdfiles.create fname)
				if(eq(type(file) 'string')
					list(false file '')
					list(true '' file)
				)
			end)
			list(true '' fh)
		)
	end

	# method for writing action log
	write = proc(file action-list)
		loopy = proc(actions result)
			if(empty(actions)
				result
				call(proc()
					action = head(actions)
					if(eq(head(action) 'start')
						# op is 'start', then skip that
						call(loopy rest(actions) result)

						call(proc()
							ser-ok ser-err encoded = call(stdser.encode action):
							if(ser-ok
								call(proc()
									as-str = call(stdbytes.string encoded)
									_ = call(stdfiles.writeln file as-str)
									call(loopy rest(actions) result)
								end)
								list(false ser-err)
							)
						end)
					)
				end)
			)
		end

		call(loopy action-list list(true ''))
	end

	# method for reading whole map
	read-all = proc(file)
		loopy = func(linelist result)
			if(empty(linelist)
				result
				call(func()
					as-bytes = call(stdbytes.str-to-bytes head(linelist))
					dec-ok dec-err action = call(stdser.decode as-bytes):
					if(dec-ok
						call(func()
							op = head(action)
							case(op
								'start' call(loopy rest(linelist) result)

								'put'
								call(func()
									key val = rest(action):
									_ _ prev-map = result:
									call(loopy rest(linelist) list(true '' put(prev-map key val)))
								end)

								'del'
								call(func()
									key = rest(action):
									_ _ prev-map = result:
									call(loopy rest(linelist) list(true '' del(prev-map key)))
								end)
							)
						end)
						list(false dec-err map())
					)
				end)
			)
		end

		lines = call(stdfiles.readlines file)
		if(eq(type(lines) 'string')
			list(false lines map())
			call(loopy lines list(true '' map()))
		)
	end

	# wraps method with file open/close handler
	file-wrapper = func(procedure)
		proc()
			open-ok open-err fh = call(open-file filename):
			retv = if(open-ok
				call(procedure fh argslist():)
				list(false open-err map())
			)
			_ = call(stdfiles.close fh)
			retv
		end
	end

	# store object
	map(
		'open'     proc() list(true '') end
		'write'    call(file-wrapper write)
		'read-all' call(file-wrapper read-all)
		'close'    proc() true end
	)
end

endns

