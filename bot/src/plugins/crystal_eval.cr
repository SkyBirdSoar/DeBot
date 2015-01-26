require "framework/plugin"
require "core_ext/process"

class CrystalEval
  include Framework::Plugin

  TEMPLATE = <<-END
begin
  p begin
    %s
  end
rescue e
  puts "\#{e.class}: #{e.message}"
end
END

  match /^>>(.+)/

  def execute msg, match
    source = TEMPLATE % [match[1]]
    run = Process.run "../sandbox/sandbox_crystal", ["eval", source], output: true, stderr: true
    output = run.output
    stderr = run.stderr
    pp stderr
    pp output

    if stderr && !stderr.strip.empty?
      playpen, crystal = separate_playpen stderr
      reply = crystal.last?
      reply = "Sorry, that took too long." if playpen.includes?("playpen: timeout triggered!")
    end

    if reply.nil? && output && !output.strip.empty?
      reply = run.success? ? output.lines.first : find_error_message(output)
    elsif run.success?
      reply = output # Return the empty string
    end

    reply ||= "Failed to run your code, sorry!"

    reply = strip_ansi_codes reply
    reply = limit_size reply

    msg.reply "#{msg.sender.nick}: #{reply}"
  end

  def separate_playpen stderr
    stderr.lines.reject(&.strip.empty?).partition &.starts_with?("playpen:")
  end

  def find_error_message output
    lines = output.lines

    # Rip out any type traces
    if separator = lines.find {|line| line =~ /^[\s=]+$/ }
      if index = lines.index(separator)
        lines = lines[0..index]
      end
    end

    # Syntax error
    syntax = lines.find {|line| line.includes?("Syntax error") }
    return syntax if syntax

    # Check if we got a traceback
    traces = lines.select {|line|
      line =~ /\/[\.\w]+:\d+:\s/ ||
      line =~ /in line \d+:/
    }
    return traces.last unless traces.empty?

    # No traceback, first line that starts with "Error" then
    lines.find &.starts_with?("Error")
  end

  def strip_ansi_codes text
    text.gsub(/\e\[(?:\d\d;)?[01]m/, "")
  end

  def limit_size text, limit=350
    text.size > limit ? "#{text[0, limit]} ..." : text
  end
end