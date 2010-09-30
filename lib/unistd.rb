# Copyright (C) 2010 Mark Somerville <mark@scottishclimbs.com>
# Released under the Lesser General Public License (LGPL) version 3.
# See COPYING.

begin
  require "ffi"
rescue LoadError
  require "rubygems"
  require "ffi"
end

module Syscalls
  extend FFI::Library
  ffi_lib "c"

  attach_function :sys_tcsetpgrp, :tcsetpgrp, [ :int, :int ], :int
  attach_function :sys_tcgetpgrp, :tcgetpgrp, [ :int ], :int

  # I can't find a nicer way to do this. Is there a method in FFI that I'm
  # missing?
  def self.raise_error(errno, possible_errors)
    possible_errors.each do |error|
      if errno == error::Errno
        raise error
      end
    end
  end

  # Set the process group identified by pgrp as the foreground process for the
  # terminal associated with fd.
  def self.tcsetpgrp(fd, pgrp)
    if(ret = sys_tcsetpgrp(fd, pgrp)) == -1
      raise_error(FFI.errno, [
                  Errno::EBADF,
                  Errno::EINVAL,
                  Errno::ENOTTY,
                  Errno::EPERM,
                  Errno::ESRCH ])
    end
    ret
  end

  # Returns the process group ID of the foreground process group on the
  # terminal associated with fd.
  def self.tcgetpgrp(fd)
    if(ret = sys_tcgetpgrp(fd)) == -1
      raise_error(FFI.errno, [
                  Errno::EBADF,
                  Errno::EINVAL,
                  Errno::ENOTTY,
                  Errno::EPERM ])
    end
    ret
  end
end
