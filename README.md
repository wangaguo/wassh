wassh
=====
A tools to manage your all server

Setting your server data & tasks. Then you can run task or command on many server.

How to use
----------
* Setting config. (wa-ssh.yml)
    * tunnel_data:
        * hawk: tunnel server data.
        * tunnel\_local\_ip
        * tunnel\_local\_port
    * sys_data: server data.
    * sys_group: group data.
* Get Help
    * $ ruby wa-ssh.rb --help
* Run task
    * $ ruby wa-ssh.rb -u youname -s server1 -t taskname
* Run command
    * $ ruby wa-ssh.rb -u youname -s server1 -c "command"
* Run multiple server
    * $ ruby wa-ssh.rb -u youname -s server1,server2 -c "command"
* Run group or groups
    * $ ruby wa-ssh.rb -u youname -g group1,group2 -c "command"

Command Help
------------
<pre>
$ ruby wa-ssh.rb --help
Usage: wa-ssh.rb [options]
    -U, --tunnel-username NAME       tunnel username
    -P, --tunnel-password PASSWORD   tunnel password
    -u, --username NAME              username
    -p, --password PASSWORD          password
    -t, --task TASK                  run task id
    -c, --command TASK               run command
    -g, --groups GROUPS              run group name, separated by comma.
    -s, --systems SYSTEMS            run system name, separated by comma.
        --show-systems
                                     show all systems.
        --show-groups
                                     show all groups.
        --show-tasks
                                     show all tasks.
    -h, --help                       Display this screen.
</pre>

Requirements
------------
* ruby 1.8 or 1.9
* require 'rubygems'
* require 'net/ssh'
* require 'yaml'
* require "logger"
* require 'optparse'

Licenses
--------
All source code is licensed under the [MIT License].
