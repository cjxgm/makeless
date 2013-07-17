<!-- vim: ft=markdown noet ts=4 sw=4 sts=0
-->
# makeless specification
`makeless` is written in `perl`, config in `perl`.

# API General Rule
<h1><code> WORK IN PROGRESS. </code></h1>

## Configuration File
a config file simply ends to mean success, or `die` to mean failure.

a config file can be `config.ml` inside a dir, which is called dir config;
it can also be `filename.ml`, where there is a file called `filename`,
which is called file config.

the config.ml under current dir is called the main config.

## Syntax
### main config
# ud = user data
userdata should use namespace ud;

# events

	require		targets that should be finished first
	append		targets that should be finished after current target.
	dir_enter	when entering a dir
	dir_leave	when leaving a dir
	file		when processing a file
	pre			when target begins
	post		when target ends
	source		file/dir to be processed
	dirty		check if file is dirty (need update)

