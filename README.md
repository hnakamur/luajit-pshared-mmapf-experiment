# luajit-pshared-mmapf-experiment

An experiment of a mutex on a memory mapped file shared between multiple processes.

This implementation is based on the answer at https://stackoverflow.com/a/53577034/1391518.
Also some code are copied and modified from [allegory-software/allegory-sdk](https://github.com/allegory-software/allegory-sdk).
Thanks!

I wrote [a blog](https://hnakamur.github.io/blog/2022/12/04/tried-shared-memory-in-luajit-and-ffi/) about this example (in Japanese).

## example usage

Run the following commands in parallel (for example, on tmux panes).
Adjust count of writers and readers as you like.

```
$ luajit pshared_shm_ex1.lua write
```

```
$ luajit pshared_shm_ex1.lua read
```

The shared memory file is created at `/dev/shm/my-shm-experiment`.
You can delete the file with:

```
$ luajit pshared_shm_ex1.lua unlink
```

or just

```
$ rm /dev/shm/my-shm-experiment
```

In this example, processes uses pthread_rwlock_t to synchronize access to the memory mapped shared memory.
The lock preference used in this example is PTHREAD_RWLOCK_PREFER_WRITER_NONRECURSIVE_NP, so it may cause reader starvation. See the following for detail.

  * [Ubuntu Manpage: pthread_rwlockattr_setkind_np, pthread_rwlockattr_getkind_np - set/get the read-write lock](https://manpages.ubuntu.com/manpages/jammy/en/man3/pthread_rwlockattr_setkind_np.3.html)
  * [embeddedmonologue - rwlock and reader/writer starvation](https://sites.google.com/site/embeddedmonologue/home/mutual-exclusion-and-synchronization/rwlock-and-reader-writer-starvation?pli=1)
