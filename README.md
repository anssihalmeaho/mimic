# mimic
It's a solution for producing new versions of data in pure
functional way but also being able to store it efficiently.
Solution is implemented in [FunL programming language](https://github.com/anssihalmeaho/funl).

## Problem
Pure functions don't change data. Instead, pure functions can produce new version of 
data based on some previous version.
But storing new version efficiently to permanent storage is difficult
as it's not known what are the changes between old and new version.

Especially here map -like structure is needed so that it can be used
as immutable data in pure functions but also being able to store it
efficienty. So it'd be like key-value data-storage that can be handled
also in purely functional way.

Also, storing mechanism should manage possibly concurrent usage.

### Use case: Backend server
One use case would be some BackEnd service which separates impure 
communication and storage handling from pure functional domain logic (kind of Clean Architecture).
Service gets request from client and gives request and current state (from storage) to
pure functional processing.
Functional processing produces response (to client) and new version of state (to storage).

![Backend server](https://github.com/anssihalmeaho/mimic/blob/main/purestate.png)

### Clean Architecture: Impedance mismatch
In Clean Architecture model domain logic (pure functional code) and impure
imperative processing (communication/data storage) are in separate layers.
Using data from some mutable database would require selection and conversion
to pure functional data in order to give it to domain part.
This is known as "impedance mismatch" problem, it requires conversions
between data formats which makes implementation more complex.

Solution is needed to avoid this.

## Solution
Solution would have two main parts: **mappy** and **base**.
**mappy** is pure functional (immutable) data structure which
acts much like **map**. It's implemented as object (map of named functions).
**base** is container for holding **mappy** value, it uses store -interface
to actually store changes.

Both **mappy** and **base** are implemented as objects so that there are
named functions/procedures in those.

**mappy** maintains log of operations in addition to map -value.
So new version of **mappy** contains map and history of changes (pure, immutable way).
When new version of **mappy** is put to **base** it uses log of changes from **mappy**
to store only changes.

**base** also manages concurrent commits (updating it with mappy new version) by
executing commit in single fiber and checking that origin **mappy** is same
as current one.

**Note**. if collision happens in commit (that other fiber has committed its version in-between)
pure functions make it possible to retry processing by taking latest **mappy** from **base**
again and giving that with other input as argument to function and commit given output again.

**base** provides also [event listener interface](https://github.com/anssihalmeaho/evenz) for listening changes in **base**.

![mappy and base](https://github.com/anssihalmeaho/mimic/blob/main/mappy.png)


## API
**mimic** module provides procedure _init-base_ which returns base-object,
store-interface object is given as argument.

### init-base
Factory procedure for creating base object. Store interface object is given as argument.
Return value is base-object (map).

```
call(init-base <map:store-interface-object>) -> <base-object>
```

## base object
Base object (map) contains named procedures.

### 'get-mappy' -method
Gets current mappy value from base.
No argument are required, return value is mappy-object.

### 'commit' -method
Put new mappy value to base (mappy given as argument).
Returns list:

1. bool: **true** if success, **false** if failure
2. string: error description

### 'new-listener' -method
Returns new [event listener interface](https://github.com/anssihalmeaho/evenz).

```
call(new-listener <matcher:func> <handler:proc>) -> listener object
```

Events that **base** publishes are:

* new mappy written to base: list('commit' changelog-list)
* base closed: list('close')


### 'close' -method
Closes base and calls close for store-interface object too.

## mappy object
Mappy object (map) contains named functions.

### Methods for reading from mappy
Following methods are used for reading mappy, similar way as
operators with same name are used for **map**:

| method name |
| ----------- |
| 'get' |
| 'getl' |
| 'in' |
| 'keys' |
| 'vals' |
| 'keyvals' |
| 'empty' |
| 'len' |

### Methods for creating new mappy based on old one
Following methods are used for creating new mappy in similar
way as operators with same name are used for **map**:

| method name |
| ----------- |
| 'put' |
| 'del' |
| 'dell' |

### Other methods of mappy
Following methods are also provided:

| method name | usage |
| ----------- | ----- |
| 'log' | gets list of operations applied (used from **base**) |
| 'map' | returns **map** value from mappy |


## Store interface
**base** uses given store interface object for storing changes
to persistent storage and for reading changes from there.

Following methods are assumed from store object:

* **'open'** for opening storage
* **'write'** for writing change-list (argument) to storage
* **'read-all'** for reading whole **map** from storage
* **'close'** for closing the storage

Client can give own implementations for store interface.
There are several example modules for possible implementations
in [store examples](https://github.com/anssihalmeaho/mimic/tree/main/stores).

There are following modules providing store interfaces:

* **inmem_store**: only in-memory store (for testing purposes)
* **logfilestore**: write-ahead log file implementation (appending always in the end)
* **valuezstore**: [ValueZ value store implementation](https://github.com/anssihalmeaho/fuvaluez), requires **ValueZ** being included


## Operations log
**mappy** uses following formats when appending to operations log (**list**):

* list('start' initial-map-value): first one, when mappy is created
* list('put' key value): key-value added to mappy
* list('del' key): key-value with given key removed from mappy


## Example
There's [Backend HTTP server example](https://github.com/anssihalmeaho/mimic/blob/main/examples/yatodo.fnl).
It provides basic CRUD services via HTTP and stores its state by using **mappy**/**base**.

## ToDo
There are several ideas which could be developed in future more:

* Language level support (overloaded operators for tailored type) so that all map utilities could be used (like in _stdfu_)
* Recursive mappy values ?
* Having verifiers for data (maybe using _stdmeta_)
* Merge -operation for several mappies ?
* Efficient version counter in mappy (comparison)
* Similar mechanism for **list** (as **mappy** is **map**)

Current implementation is just some kind of study to demonstrate the basic idea.
