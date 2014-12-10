# PreforkEngine

a simple prefork server framework. ruby port of perl's Parallel::Prefork
PreforkEngine supports graceful shutdown and runtime reconfiguration

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'prefork_engine'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install prefork_engine

## Usage

```
pm = PreforkEngine.new(
  "max_workers" => 3
  "spawn_interval" => 1,
  "err_respawn_interval" => 3,
  "trap_signals" => {
    "TERM" => "TERM",
    "HUP"  => "TERM"
  }
)

while !pm.signal_received.match(/^(TERM|HUP)$/)
  pm.start {
    ... do some work within the child process ...
  }
end

pm.wait_all_children
```

## METHODS

### new

create instance. accepts following attributes

#### max_workers

number of worker processes (default: 10)

#### spawn_interval

nterval in seconds between spawning child processes unless a child process exits abnormally (default: 0)

#### err_respawn_interval

number of seconds to deter spawning of child processes after a worker exits abnormally (default: 1)

#### trap_signals

Hash of signals to be trapped. Manager process will trap the signals listed in the keys of the hash, and send the signal specified in the associated value (if any) to all worker processes. If the associated value is a String then it is treated as the name of the signal to be sent immediately to all the worker processes. If the value is an Array the first value is treated the name of the signal and the second value is treated as the interval (in seconds) between sending the signal to each worker process.

#### on_child_reap

Proc object that is called when a child is reaped. Receives the instance to the current PreforkEngine, the child's pid, and its exit status.

#### before_fork

#### after_fork

Proc object that are called in the manager process before and after fork, if being set

### start

The main routine. this method requires Proc object.

`start` forks child processes and executes given Proc object within the child processes. 

The start function returns true within manager process upon receiving a signal specified in the `trap_signals`

### signal_all_children

Sends singal to all worker processes

### wait_all_children

waits until all workers exit

## SEE ALSO

https://metacpan.org/pod/Parallel::Prefork

## Contributing

1. Fork it ( https://github.com/kazeburo/prefork_engine/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
