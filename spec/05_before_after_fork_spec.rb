require 'spec_helper'

describe PreforkEngine do
  it 'before_after_fork' do
    i = 0
    j = 0
    pm = PreforkEngine.new(
      "max_workers" => 3,
      "trap_signals" => {
         "TERM" => "TERM",
      },
      "before_fork" => proc { |pm2|
        i += 1
      },
      "after_fork" => proc { |pm3|
        j += 1
      }
    )
    while pm.signal_received != "TERM"
      pm.start {
        if i == 10 then
          Process.kill("TERM", pm.manager_pid)
        end
      }
    end
    pm.wait_all_children()
    expect(i).to be >= 10
    expect(j).to be >= 10
  end
end
