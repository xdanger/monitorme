#/usr/local/bin/ruby

# 用法：ruby deploy.rb

require 'rubygems'
require 'net/sftp'

require 'prepend'

@config["hosts"].each {|name, host|
  unless host.has_key? 'login'
    next
  end
  if host['login'].include? "@"
    info = host['login'].match(/^(.+)@(.+)$/)
    user = info[1]; addr = info[2]
  else
    user = host['login']; addr = name
  end
  Net::SFTP.start(addr, user) {|sftp|
    begin
      dir = sftp.opendir! host['deploy_dir']
    rescue Net::SFTP::StatusException
      puts "打开#{host['deploy_dir']}失败 @#{name}"
      puts "正在创建目录"
      sftp.mkdir(host['deploy_dir']).wait
    end
    puts "正在部署到#{name}:#{host['deploy_dir']}"
    ['config.yml', 'prepend.rb', 'monitor.rb'].each {|f|
      upld = sftp.upload("#{CURRENT_PATH}/#{f}", "#{host['deploy_dir']}/#{f}")
      upld.wait
    }
  }
}

puts "OK"