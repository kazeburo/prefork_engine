require 'spec_helper'
require "tempfile"

describe PreforkEngine do
  it 'has a version number' do
    expect(PreforkEngine::VERSION).not_to be nil
  end

  it 'base' do
    max_workers = 10
    reaped = 0
    pm = PreforkEngine.new(
      "max_workers" => max_workers,
      "spawn_interval" => 0,
      "on_child_reap" => proc {
        reaped += 1
      },
    )
    expect(pm).to be_an_instance_of(PreforkEngine)

    temp = Tempfile.open(['01-base-', 'txt'])
    temp.syswrite('0')
    temp_path = temp.path
    ppid = $$
    
    while ! pm.signal_received.match(/^TERM$/)
      pm.start {
        f = open(temp_path, "r+")
        f.flock(File::LOCK_EX)
        c = f.sysread(10)
        c = c.to_i + 1
        f.sysseek(0,0)
        f.syswrite(c.to_s)
        f.flock(File::LOCK_UN)
        Signal.trap("TERM", proc {
          f.flock(File::LOCK_EX)
          f.sysseek(0,0)
          c = f.sysread(10)
          c = c.to_i + 1
          f.sysseek(0,0)
          f.syswrite(c.to_s)
          f.flock(File::LOCK_UN)
          exit!(true)
        })
        if c == max_workers then
          Process.kill("TERM",ppid)
        end
        sleep 100
      } # pm.start
    end
    pm.wait_all_children()

    temp.sysseek(0,0)
    c = temp.sysread(10)
    c = c.to_i

    expect(c).to eql(max_workers * 2)
    expect(reaped).to eql(max_workers)
    temp.close;
  end
end
