require "rubygems"
require "test/unit"
require File.dirname(__FILE__) + '/../lib/signal'

class SignalTest < Test::Unit::TestCase

  if defined? Syscalls.sigprocmask
    def test_sigprocmask_with_valid_how_parameter
      handler_called = false
      Signal.trap("USR1") { handler_called = true }

      mask = Syscalls::Sigset_t.new.to_ptr
      new_mask = Syscalls::Sigset_t.new
      Syscalls.sigemptyset(mask)
      Syscalls.sigemptyset(new_mask)
      Syscalls.sigaddset(mask, "USR1")

      assert_equal 0, Syscalls.sigprocmask(Syscalls::SIG_BLOCK, mask, nil)
      assert_equal 0, Syscalls.sigprocmask(Syscalls::SIG_BLOCK, nil, new_mask)
      assert_not_equal 0, new_mask[:__val].to_ptr.read_long

      fork { Process.kill("USR1", Process.pid) }
      Process.waitpid
      sleep 0.5
      assert !handler_called
    end

    def test_sigprocmask_with_invalid_how_parameter
      mask = Syscalls::Sigset_t.new.to_ptr
      assert_raises(Errno::EINVAL) { Syscalls.sigprocmask(100, mask, nil) }
    end
  end

  def test_sigemptyset_using_a_valid_sigset
    sigset = Syscalls::Sigset_t.new.to_ptr
    assert_equal 0, Syscalls.sigemptyset(sigset)
  end

  def test_sigemptyset_using_an_invalid_sigset_raises
    assert_raises(ArgumentError) { Syscalls.sigemptyset(1) }
  end

  def test_sigaddset_with_valid_signal
    sigset = Syscalls::Sigset_t.new
    ptr = sigset.to_ptr
    Syscalls.sigemptyset(ptr)

    assert_equal 0, Syscalls.sigaddset(ptr, "ALRM")
    bitmask = sigset[:__val].to_ptr.read_long
    assert_equal 0, bitmask >> Signal.list["ALRM"]

    assert_equal 0, Syscalls.sigaddset(ptr, "CHLD")
    bitmask = sigset[:__val].to_ptr.read_long - bitmask
    assert_equal 0, bitmask >> Signal.list["CHLD"]
  end

  def test_sigaddset_with_an_invalid_signal_raises
    sigset = Syscalls::Sigset_t.new.to_ptr
    assert_raises(TypeError) { Syscalls.sigaddset(sigset, "RAISE") }
    assert_raises(Errno::EINVAL) { Syscalls.sigaddset(sigset, 12345) }
  end

  def test_sigdelset_with_valid_signal
    sigset = Syscalls::Sigset_t.new
    ptr = sigset.to_ptr
    Syscalls.sigemptyset(ptr)

    Syscalls.sigaddset(ptr, "ALRM")
    bitmask = sigset[:__val].to_ptr.read_long

    assert_equal 0, Syscalls.sigdelset(ptr, "CHLD")
    assert_equal bitmask, sigset[:__val].to_ptr.read_long

    assert_equal 0, Syscalls.sigdelset(ptr, "ALRM")
    assert_equal 0, sigset[:__val].to_ptr.read_long
  end

  def test_sigdelset_with_an_invalid_signal_raises
    sigset = Syscalls::Sigset_t.new.to_ptr
    assert_raises(TypeError) { Syscalls.sigdelset(sigset, "RAISE") }
    assert_raises(Errno::EINVAL) { Syscalls.sigdelset(sigset, 12345) }
  end

  def test_sigwait_with_valid_sigset
    mask = Syscalls::Sigset_t.new.to_ptr
    Syscalls.sigemptyset(mask)
    Syscalls.sigaddset(mask, "CHLD")

    # this works on my 64 Linux machine, but calling sigwait() without calling
    # sigprocmask() is actually undefined. 
    if defined? Syscalls.sigprocmask
      Syscalls.sigprocmask(Syscalls::SIG_SETMASK, mask, nil)
    end

    # this is needed to make Ruby < 1.8.7 pass this test (very likely due to a
    # bug in those verions where rt_sigprocmask is called all the time).
    Signal.trap("CHLD") {}

    start_time = Time.now
    fork { sleep 2 }

    assert_equal Signal.list["CHLD"], Syscalls.sigwait(mask)
    assert Time.now >= start_time + 2
    Process.waitpid
  end

  def test_sigwait_with_valid_signals_array
    # this is needed to make Ruby < 1.8.7 pass this test (very likely due to a
    # bug in those verions where rt_sigprocmask is called all the time).
    Signal.trap("CHLD") {}

    start_time = Time.now
    fork { sleep 2 }

    # this works on my 64 Linux machine, but calling sigwait() without calling
    # sigprocmask() is actually undefined. 
    assert_equal Signal.list["CHLD"], Syscalls.sigwait([ "CHLD" ])
    assert Time.now >= start_time + 2
    Process.waitpid
  end

  def test_sigsuspend_with_valid_sigset
    mask = Syscalls::Sigset_t.new.to_ptr
    Syscalls.sigemptyset(mask)
    Syscalls.sigaddset(mask, "USR1")
    if defined? Syscalls.sigprocmask
      Syscalls.sigprocmask(Syscalls::SIG_SETMASK, mask, nil)
    end

    Signal.trap("CHLD") { Process.waitpid }

    start_time = Time.now
    fork { sleep 2 }

    assert_equal(-1, Syscalls.sigsuspend(mask))
    assert Time.now >= start_time + 2
  end

  def test_sigsuspend_with_valid_array_of_signals
    Signal.trap("CHLD") { Process.waitpid }

    start_time = Time.now
    fork { sleep 2 }

    assert_equal(-1, Syscalls.sigsuspend([ "USR1", "USR2" ]))
    assert Time.now >= start_time + 2
  end
end
