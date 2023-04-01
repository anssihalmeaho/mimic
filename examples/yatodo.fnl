
ns main

import stdhttp
import stdjson

# pure functional handling is in following functions
get-item-by-key = func(mappy key)
	found value = call(get(mappy 'getl') key):
	if(found
		list(200 map(key value))
		list(404 'key not found')
	)
end

get-all-items = func(mappy)
	list(200 call(get(mappy 'map')))
end

put-item-by-key = func(mappy new-item)
	key value = head(keyvals(new-item)):
	has-key-already = call(get(mappy 'in') key)
	if(has-key-already
		list(404 'key already found' mappy)

		call(func()
			new-mappy = call(get(mappy 'put') key value)
			list(201 '' new-mappy)
		end)
	)
end

del-item-by-key = func(mappy key)
	found new-mappy = call(get(mappy 'dell') key):
	if(found
		list(200 '' new-mappy)
		list(404 'key not found' mappy)
	)
end

# following procedures are impure part
get-item = proc(base w r)
	mappy = call(get(base 'get-mappy'))
	key = last(split(get(r 'URI') '/'))
	status-code result = call(get-item-by-key mappy key):
	_ _ response = call(stdjson.encode result):
	call(stdhttp.write-response w status-code response)
end

del-item = proc(base w r)
	mappy = call(get(base 'get-mappy'))
	key = last(split(get(r 'URI') '/'))
	status-code result new-mappy = call(del-item-by-key mappy key):
	_ = case(status-code
		200 call(get(base 'commit') new-mappy)
		'not changed if item was not found'
	)
	_ _ response = call(stdjson.encode result):
	call(stdhttp.write-response w status-code response)
end

post-item = proc(base w r)
	mappy = call(get(base 'get-mappy'))
	ok err new-item = call(stdjson.decode get(r 'body')):
	status-code result new-mappy = cond(
		not(ok)
		list(400 err 'none')

		not(eq(type(new-item) 'map'))
		list(400 'item should be JSON object' 'none')

		not(eq(len(new-item) 1))
		list(400 'exactly one item should be given' 'none')

		call(put-item-by-key mappy new-item)
	):
	_ = case(status-code
		201 call(get(base 'commit') new-mappy)
		'not changed if failure'
	)
	_ _ response = call(stdjson.encode result):
	call(stdhttp.write-response w status-code response)
end

get-all = proc(base w r)
	mappy = call(get(base 'get-mappy'))
	status-code result = call(get-all-items mappy):
	_ _ response = call(stdjson.encode result):
	call(stdhttp.write-response w status-code response)
end

# constructor procedures for HTTP handlers
new-item-specific-handler = proc(base)
	proc(w r)
		case(get(r 'method')
			'GET'    call(get-item base w r)
			'DELETE' call(del-item base w r)
		)
	end
end

new-items-handler = proc(base)
	proc(w r)
		case(get(r 'method')
			'GET'  call(get-all base w r)
			'POST' call(post-item base w r)
		)
	end
end

# main procedure
main = proc(port)
	#import inmem_store
	import logfilestore
	import mimic
	import stdhttp

	store = call(logfilestore.get-store 'oplog.txt')
	#store = call(inmem_store.get-store)
	base = call(mimic.init-base store)

	mux = call(stdhttp.mux)
	_ = call(stdhttp.reg-handler mux '/todo/' call(new-item-specific-handler base))
	_ = call(stdhttp.reg-handler mux '/todo' call(new-items-handler base))
	address = plus(':' str(port))

	_ = print('...serving...')
	call(stdhttp.listen-and-serve mux address)
end

endns

