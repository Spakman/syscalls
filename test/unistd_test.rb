require "test/unit"
require File.dirname(__FILE__) + '/../lib/unistd'

class UnistdTest < Test::Unit::TestCase
  def test_tcgetpgrp
    assert_equal Process.getpgrp, Syscalls.tcgetpgrp(0)
  end

  def test_tcgetpgrp_with_invalid_fd
    assert_raises(Errno::EBADF) { Syscalls.tcgetpgrp(9999) }
  end

  def test_tcsetpgrp
    # Our test process wants to be able to be foregrounded.
    Signal.trap(:TTOU, "IGNORE")

    # Block this so that EIO is raised when we try to read STDIN from the
    # background.
    Signal.trap(:TTIN, "IGNORE")

    pid = fork do
      Process.setpgid(Process.pid, Process.pid) rescue Errno::EACCES
      sleep 0.5
    end
    Process.setpgid(pid, pid) rescue Errno::EACCES

    assert_equal 0, Syscalls.tcsetpgrp(0, pid)
    assert_raises(Errno::EIO) { STDIN.read }

    Process.wait pid
  end

  def test_tcsetpgrp_with_invalid_process
    assert_raises(Errno::ESRCH) { Syscalls.tcsetpgrp(0, Process.pid+1) }
  end

  def test_tcsetpgrp_process_in_different_session
    assert_raises(Errno::EPERM) { Syscalls.tcsetpgrp(0, 1) }
  end
end
