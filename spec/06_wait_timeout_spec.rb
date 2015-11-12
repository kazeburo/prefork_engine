require 'spec_helper'

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
    term_req = 0
    Signal.trap("TERM",
                proc {
                  term_req += 1
                  exit!(0) if term_req > 3
                })
    sleep 1
    Process.kill("TERM", pm.manager_pid)
    while true
      sleep 1
    end
  }
end

send_term = 0
while pm.wait_all_children(1) > 0
  pm.signal_all_children("TERM")
  send_term += 1
end

describe PreforkEngine do
  it 'wait_timeout' do
    expect(send_term).to be >= 3
  end
end

