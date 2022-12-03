# luajit-pshared-mmapf-experiment

An experiment of a mutex on a memory mapped file shared between multiple processes.

This implementation is based on the answer at https://stackoverflow.com/a/53577034/1391518.
Thanks!

## example session

I ran the following commands in parallel on tmux panes.

```
$ luajit pshared_mmapf_ex1.lua 0.0002
opened file
before lock
locked
unlocked
```

```
$ luajit pshared_mmapf_ex1.lua
try creating file after open err=ENOENT
created file
before lock
locked
unlocked
```

```
$ luajit pshared_mmapf_ex1.lua
try creating file after open err=EACCES
waiting for other process to create file
opened file just created by other process
before lock
locked
unlocked
```
