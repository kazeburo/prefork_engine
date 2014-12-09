require 'spec_helper'
require "tempfile"

describe PreforkEngine do
  it 'reconfigure' do
    pm = PreforkEngine.new(
      "max_workers" => 1,
      "trap_signals" => {
        "TERM" => 'TERM',
        "HUP"  => 'TERM',
      },
    )
    expect(pm).to be_an_instance_of(PreforkEngine)
    c = 0
    while pm.signal_received != "TERM"
      c += 1
      pm.start {
        sleep 1
        if c == 1 then
          Process.kill("HUP",pm.manager_pid)
        else
          Process.kill("TERM",pm.manager_pid)
        end
      }
    end
    pm.wait_all_children();
    expect(c).to eql(2)
  end
end
