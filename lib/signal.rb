# Copyright (C) 2010 Mark Somerville <mark@scottishclimbs.com>
# Released under the Lesser General Public License (LGPL) version 3.
# See COPYING

require "ffi"

module Syscalls
  extend FFI::Library
  ffi_lib "c"

  class Sigset_t < FFI::Struct
    layout  :__val, [ :ulong, 1024 / (8 * FFI::MemoryPointer.new(:ulong).size) ]
  end

  attach_function :sys_sigprocmask, :sigprocmask, [ :int, :pointer, :pointer ], :int
  attach_function :sys_sigwait, :sigwait, [ :pointer, :pointer ], :int
  attach_function :sys_sigemptyset, :sigemptyset, [ :pointer ], :int
  attach_function :sys_sigaddset, :sigaddset, [ :pointer, :int ], :int
  attach_function :sys_sigdelset, :sigdelset, [ :pointer, :int ], :int
  attach_function :sys_sigsuspend, :sigsuspend, [ :pointer ], :int

  SIG_BLOCK = 0
  SIG_UNBLOCK = 1
  SIG_SETMASK = 2

  # Ruby < 1.8.7 calls rb_sigprocmask *loads*, making this unusable.
  if RUBY_VERSION >= "1.8.7"
    # Fetch and/or change the signal mask of the calling thread.
    def self.sigprocmask(how, set, oldset)
      if ret = sys_sigprocmask(how, set, oldset) < 0
        raise Errno::EINVAL
      end
      0
    end
  end

  # Initializes the given set to be empty.
  def self.sigemptyset(sigset)
    if ret = sys_sigemptyset(sigset) < 0
      raise Errno::EINVAL
    end
    0
  end

  # Adds a signal to a set.
  def self.sigaddset(sigset, signal)
    if signal.is_a? String
      signal = Signal.list[signal]
    end

    if ret = sys_sigaddset(sigset, signal) < 0
      raise Errno::EINVAL
    end
    0
  end

  # Removes a signal from a set.
  def self.sigdelset(sigset, signal)
    if signal.is_a? String
      signal = Signal.list[signal]
    end

    if ret = sys_sigdelset(sigset, signal) < 0
      raise Errno::EINVAL
    end
    0
  end

  # Suspends execution of the current thread until the delivery of one of the
  # given signals.
  #
  # Arg can be either an array of signal names or an FFI::MemoryPointer to a
  # Sigset_t.
  def self.sigwait(arg)
    if arg.is_a? FFI::MemoryPointer
      sigset = arg
    else
      sigset = sigset_for_signals(arg)
    end

    received_signal = FFI::MemoryPointer.new(:pointer)

    if ret = sys_sigwait(sigset, received_signal) > 0
      raise Errno::EINVAL
    end
    received_signal.read_int
  end

  # Temporarily replaces the signal mask of the calling process and suspends
  # the process until delivery of a signal whose action is to invoke a signal
  # handler or to terminate the process.
  #
  # Arg can be either an array of signal names or an FFI::MemoryPointer to a
  # Sigset_t.
  def self.sigsuspend(arg)
    if arg.is_a? FFI::MemoryPointer
      sigset = arg
    else
      sigset = sigset_for_signals(arg)
    end

    sys_sigsuspend(sigset)
    -1
  end

  # Convenience method to populate a Sigset_t with an array of signals
  def self.sigset_for_signals(signals)
    sigset = Sigset_t.new.to_ptr

    sigemptyset(sigset)

    signals.each do |name|
      sigaddset(sigset, name)
    end
    sigset
  end
end
