require 'spec_helper'
require "tempfile"
require 'tmpdir'

describe PreforkEngine do
  it 'interval' do
    d = Dir.mktmpdir
    pid = fork
    if pid != nil then
      # parent
      sleep 0.5
      expect(Dir.glob("#{d}/status*").length).to eql(1)
      sleep 1
      expect(Dir.glob("#{d}/status*").length).to eql(2)
      sleep 1
      expect(Dir.glob("#{d}/status*").length).to eql(3)
      sleep 1
      expect(Dir.glob("#{d}/status*").length).to eql(3)
      Process.kill("TERM",pid)
      sleep 0.5
      expect(Dir.glob("#{d}/status*").length).to eql(2)
      sleep 2
      expect(Dir.glob("#{d}/status*").length).to eql(1)
      Process.waitpid(pid)
    else
      pm = PreforkEngine.new(
        "max_workers" => 3,
        "spawn_interval" => 1,
        "trap_signals" => {
          "TERM" => ["TERM",2],
          "HUP"  => "TERM"
        }
      )
      while pm.signal_received != "TERM"
        pm.start {
          temp = Tempfile.open(['status', 'txt'],d)
          term_req = 0
          Signal.trap("TERM", proc {
            term_req += 1
          })
          while term_req == 0
            sleep 0.01
          end
          temp.close!
        }
      end
      pm.wait_all_children
      exit!()
    end
    FileUtils.remove_entry_secure(d)
  end
end
