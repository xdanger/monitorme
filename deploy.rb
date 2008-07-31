#/usr/local/bin/ruby

# 用法：ruby deploy.rb

require 'rubygems'
require 'net/sftp'

require 'prepend'

TO_DEPLY_FILES = ['config.yml','prepend.rb', 'monitor.rb', 'test-dl.sh', 'test-url.sh']

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
      puts "打开#{host['deploy_dir']}失败 @#{name}，正在创建目录"
      sftp.mkdir(host['deploy_dir']).wait
      sftp.mkdir(host['deploy_dir'] + '/log').wait
    end
    puts "正在部署到#{name}:#{host['deploy_dir']}"
    sftp.dir.entries("#{host['deploy_dir']}/log").map { |e|
      sftp.remove("#{host['deploy_dir']}/log/#{e.name}")
    }
    TO_DEPLY_FILES.each {|f|
      sftp.upload("#{CURRENT_PATH}/#{f}", "#{host['deploy_dir']}/#{f}").wait
    }
  }
}

puts "OK"
