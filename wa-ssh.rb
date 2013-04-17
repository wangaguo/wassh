#!/usr/bin/env ruby
# encoding: utf-8
require 'rubygems'
require 'net/ssh'
require 'yaml'
require "logger"
require 'optparse'
$KCODE = 'u'
#$:.unshift(File.join(File.dirname(__FILE__)))
#Dir.chdir File.join(File.dirname(__FILE__))

def putslogger(type, msg)
  puts msg
  case type
    when :i then $log.info msg
    when :w then $log.warn msg
    when :e then $log.error msg
  end
end

def keyin(caption)
  begin
    print "#{caption}: "
    #system "stty -echo"
    data = $stdin.gets.chomp
  ensure
    #system "stty echo"
    puts ""
  end 
end

# Arguments ready
options = {}

 optparse = OptionParser.new do|opts|
   opts.banner = "Usage: wa-ssh.rb [options]"

   options[:tunnel_username] = nil
   opts.on('-U', '--tunnel-username NAME', 'tunnel username' ) do |username|
     options[:tunnel_username] = username 
   end

   options[:password] = nil
   opts.on('-P', '--tunnel-password PASSWORD', 'tunnel password' ) do |password|
     options[:tunnel_password] = password 
   end

   options[:username] = nil
   opts.on('-u', '--username NAME', 'username' ) do |username|
     options[:username] = username 
   end

   options[:password] = nil
   opts.on('-p', '--password PASSWORD', 'password' ) do |password|
     options[:password] = password 
   end

   options[:task] = nil
   opts.on('-t', '--task TASK', 'run task id' ) do |task|
     options[:task] = task 
   end

   options[:groups] = nil
   opts.on('-g', '--groups GROUPS', 'run group name, separated by comma.' ) do |groups|
     options[:groups] = groups
   end

   options[:systems] = nil
   opts.on('-s', '--systems SYSTEMS', 'run system name, separated by comma.' ) do |systems|
     options[:systems] = systems 
   end

   options[:show_systems] = nil
   opts.on('', '--show-systems', 'show all systems.' ) do
     options[:show_systems] = true 
   end

   options[:show_groups] = nil
   opts.on('', '--show-groups', 'show all groups.' ) do
     options[:show_groups] = true 
   end

   options[:show_tasks] = nil
   opts.on('', '--show-tasks', 'show all tasks.' ) do
     options[:show_tasks] = true 
   end

   opts.on( '-h', '--help', 'Display this screen.' ) do
     puts opts
     exit
   end
 end
optparse.parse!

#init data
Dir.chdir(".")
$log = Logger.new("ssh.log")
$log.level = Logger::INFO
$log.formatter = Logger::Formatter.new

conf = YAML.load_file('wa-ssh.yml')
sys_data = conf["sys_data"]
sys_group = conf["sys_group"]
tasks = conf["tasks"]
hawk = conf["hawk"]
tunnel_local_ip = conf["tunnel_local_ip"] 
tunnel_local_port = conf["tunnel_local_port"]

#tunnel_session = Net::SSH.start(hawk["ip"], login, {:password => pw, :port => hawk["port"]})
#tunnel_session.forward.cancel_local(tunnel_local_port, tunnel_local_ip)
#tunnel_session.forward.cancel_local(tunnel_local_port)
tunnel_thread = ""
msg = ""
group_id = "" 
task_id = "1"
run_sys = []

group_id = options[:groups] unless options[:groups].nil?
group_id.gsub(" ", "").split(",").map{|g| run_sys += sys_group[g] }
options[:systems].gsub(" ", "").split(",").map{|s| run_sys << s  }  unless options[:systems].nil?
task_id = options[:task] unless options[:task].nil?

if options[:show_systems]
  sys_data.each do |s|
    puts s.inspect
  end
  exit
end
if options[:show_groups]
  sys_group.each do |g|
    puts g.inspect
  end
  exit
end
if options[:show_tasks]
  tasks.each do |t, v|
    puts "#{t}: #{v["descr"]}"
  end
  exit
end
#account & password
login = options[:username]
pw = options[:password]
tunnel_login = options[:tunnel_username]
tunnel_pw = options[:tunnel_password]
if pw == nil
  begin
    print "Password: "
    system "stty -echo"
    pw = $stdin.gets.chomp
  ensure
    system "stty echo"
    puts ""
  end
end
if tunnel_login == nil 
  tunnel_login = login
  tunnel_pw = pw
else
  if tunnel_pw == nil
    begin
      print "Tunnel Password: "
      system "stty -echo"
      tunnel_pw = $stdin.gets.chomp
    ensure
      system "stty echo"
      puts ""
    end
  end
end

#start
task_before = tasks[task_id]["before"]
if task_before
  begin
    if task_before.class == Array
      eval(task_before.join("\n"))
    else
      eval(task_before)
    end
  rescue Exception => e
    output = e
  end
end

run_sys.each do |name|
  begin
    s = sys_data[name]
    putslogger :i, "----- run #{name} ------------------"
    if s.nil?
      putslogger :e, "server data is not exists!"
      next 
    end
    #s[:hawk] ? sn = hawk : sn = s
    if s["hawk"]
      tunnel_session = Net::SSH.start(hawk["ip"], login, {:password => pw, :port => hawk["port"]})
      #tunnel_session.forward.local(tunnel_local_ip, tunnel_local_port, s[:ip], s[:port])
      tunnel_session.forward.local(tunnel_local_port, s["ip"], s["port"])
      tunnel_thread = Thread.new do
        tunnel_session.loop {true}
      end
      s["ip"] = tunnel_local_ip
      s["port"] = tunnel_local_port
    end

    Net::SSH.start(s["ip"], login, {:password => pw, :port => s["port"]}) do |ssh|
      case task_id
        when "1" #check login
          output = ssh.exec!("hostname")
          output = "#{output} account:#{login} ssh ok"
        when "2" #check memorry
          output = ssh.exec!("uname -s")
          if(output =~ /^Linux/)
            output = "#{ssh.exec!("cat /proc/meminfo |grep MemTotal")}"
            output = "Linux: #{output}"
          else
            output = "#{ssh.exec!("sysctl -a | grep hw.physmem")}"
            output = "FreeBSD: #{output}"
          end
          output = "#{name}: #{output}"
        when "3" #check system users
          output = ssh.exec!("cat /etc/passwd |egrep '(username1|username2|username3)'")
          output = "#{name}:\n #{output}"
        when "4" #check disk space
          output = ssh.exec!("df -hP |egrep '^(/dev/|\\s)'")
        when "5" #check disk space and up then 95%
          output = ssh.exec!("df -hP |egrep '^(/dev/|\\s)' |egrep '9[0-9]%'")
        when "6" #check big file
          output = ssh.exec!("find /var/log /home " +
                                  " -type f -size +10M -name '*log' -exec ls -lFh {} \\;")
          output = output.split("\n").map{|l| if l !~ /^find:/ then l end}.compact.join("\n") unless output.nil?
        when "7" #check vt support
          output = ssh.exec!("uname -s")
          if(output =~ /^Linux/)
            output = "Linux: VT:"
            if "#{ssh.exec!("egrep -c '(vmx|svm)' /proc/cpuinfo")}".to_i > 0
              output += "yes"
            else
              output += "no"
            end
            output += ", ncpu:"
            output += ssh.exec!("egrep -c 'cpu family' /proc/cpuinfo") 
          else
            output = "FreeBSD: VT:" 
            if "#{ssh.exec!("grep Features /var/run/dmesg.boot | egrep -ic '(vmx|svm)'")}".to_i > 0
              output += "yes"
            else
              output += "no"
            end
            output += ", ncpu:"
            output += "#{ssh.exec!("sysctl -a | grep hw.ncpu")}".match(/\d+/).to_s
          end 
          output = "#{name}: #{output}"
        else
          task_code = tasks[task_id]["code"]
          if task_code
            begin
              if task_code.class == Array
                eval(task_code.join("\n"))
              else
                eval(task_code)
              end
            rescue Exception => e
              output = e
            end
          end
      end

      #puts output
      #msg += output + "\n"
      putslogger :i, output
      if s["hawk"]
        #puts "*********************************"
        #tunnel_session.forward.cancel_local(tunnel_local_port, tunnel_local_ip)
        tunnel_session.forward.cancel_local(tunnel_local_ip)
        Thread.kill(tunnel_thread)
        tunnel_local_port += 1
      end
    end
  rescue Net::SSH::AuthenticationFailed
    putslogger :e, "account or password error"
  rescue
    #tunnel_session.forward.cancel_local(tunnel_local_port, tunnel_local_ip)
    putslogger :e, "error for #{name}"
    putslogger :e, "#{$!}\n#{$@}"
  end
end
#$log.info msg

