class Result
  attr_accessor :host, :cmd, :stdout, :stderr, :exit_code, :output,
                :raw_output, :raw_stdout, :raw_stderr
  def initialize(host = nil, cmd = nil, stdout = '', stderr = '',
                 exit_code = nil, output = '', raw_output = '',
                 raw_stdout = '', raw_stderr = '')
    @host       = host
    @cmd        = cmd
    @stdout     = stdout
    @stderr     = stderr
    @exit_code  = exit_code
    @output     = output
    @raw_output = raw_output
    @raw_stdout = raw_stdout
    @raw_stderr = raw_stderr
  end

  def log
    Log.debug
    Log.debug "<STDOUT>\n#{host}: #{stdout}\n</STDOUT>"
    Log.debug "<STDERR>\n#{host}: #{stderr}\n</STDERR>"
    Log.debug "#{host}: Exited with #{exit_code}"
  end
end
