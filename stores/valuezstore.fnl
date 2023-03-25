
ns valuezstore

get-store = proc(db-name)
	import stdpp
	import stdvar
	import valuez
	import stdfu

	# in principal it might be good that whole thing
	# would be done either:
	# 1) in context of server fiber
	# or
	# 2) inside valuez transaction

	store-ref = call(stdvar.new map('open' false))
	colname = 'storer'

	put-kv = proc(col action)
		key value = rest(action):
		# we are not checking if key exists already
		# its checked already earlier
		call(valuez.put-value col list(key value))
	end

	# method for writing action log
	write = proc(action-list)
		write-actions = proc(actions result)
			db = get(info 'db')
			col = get(info 'col')

			if(empty(actions)
				result
				if(head(result)
					call(proc()
						action = head(actions)
						op = head(action)
						case(op
							'start'
							call(write-actions rest(actions) result)

							'put'
							call(proc()
								put-ok put-err = call(put-kv col action):
								if(put-ok
									call(write-actions rest(actions) result)
									list(false put-err)
								)
							end)

							'del'
							call(proc()
								key = rest(action):
								_ = call(valuez.take-values col func(x) eq(head(x) key) end)
								# should it be checked that (at least) one item is taken...
								call(write-actions rest(actions) result)
							end)
						)
					end)
					result
				)
			)
		end

		info = call(stdvar.value store-ref)
		if(get(info 'open')
			call(write-actions action-list list(true ''))
			list(false 'storage closed')
		)
	end

	# method for reading whole map
	read-all = proc()
		info = call(stdvar.value store-ref)
		if(get(info 'open')
			call(proc()
				db = get(info 'db')
				col = get(info 'col')
				kv-pairs = call(valuez.get-values col func(x) true end)
				as-map = call(stdfu.pairs-to-map kv-pairs)
				list(true '' as-map)
			end)
			list(false 'storage closed')
		)
	end

	open-col = proc(db)
		col-ok col-err colvalue = call(valuez.get-col db colname):
		if(col-ok
			list(col-ok col-err colvalue)
			call(valuez.new-col db colname)
		)
	end

	# method for opening db/collection
	open = proc()
		open-ok open-err db = call(valuez.open db-name):
		if(open-ok
			call(proc()
				col-ok col-err colvalue = call(open-col db):
				_ = if(col-ok
					call(stdvar.set store-ref map('db' db 'col' colvalue 'open' true))
					'no db available'
				)
				list(col-ok col-err)
			end)
			list(false open-err)
		)
	end

	# method for closing db/collection
	close = proc()
		info = call(stdvar.value store-ref)
		_ = if(get(info 'open')
			call(valuez.close get(info 'db'))
			'already closed'
		)
		_ = call(stdvar.set store-ref map('open' false))
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

