#!/usr/local/bin/ruby

require 'resolv'
require 'ping'
require 'socket'
require 'net/http'
require 'uri'
require 'timeout'
require 'digest'

require 'prepend'

CONNECTION_TIMEOUT = 10

def alert_im(msg)
  puts msg
  url = URI.parse("http://api.fanfou.com/statuses/update.xml")
  req = Net::HTTP::Post.new(url.path)
  req.basic_auth @config['fanfou']['username'], @config['fanfou']['password']
  req.set_form_data({ 'status' => msg }, ';')
  res = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
end

@label = '未知'
@host  = Socket.gethostname
# 设置已知宿主的名称和 dns
if @config["hosts"].has_key? @host
  host = @config["hosts"][@host]
  @label = host["label"]
  @dns = host["dns"]
end
@config["targets"].each {|target|
#  Thread.new {
    skip = false
    if @config['hosts'][@host].has_key? 'skip_targets'
      @config['hosts'][@host]['skip_targets'].each {|u|
        if u == target['url']
          skip = true
        end
      }
      if skip
        next
      end
    end
    url = URI.parse(target['url'])
    ips = []
    unless @dns.nil?
      res = Resolv::DNS.new(:nameserver => @dns, :search => [''], :ndots => 1)
    else
      res = Resolv::DNS.new()
    end
    # 开始解析 DNS，控制超时
    begin
      Timeout::timeout(RESOLV_TIMEOUT) {
        res.each_address(url.host) do |ip|
          ip = ip.to_s
          ips.delete_if {|x| x == ip }
          ips.push(ip)
        end
      }
    rescue Timeout::Error
      alert_im "DNS解析超过#{RESOLV_TIMEOUT}秒 from #{@label}"
    end
    ips.each {|ip|
#      Thread.new {
        log = CURRENT_PATH + '/log/' + Digest::SHA1.hexdigest(ip + target['url'])
        msg = "[#{Time.now.strftime('%H:%M:%S')}] #{url.host} : #{ip} from #{@label} "
        warn = false
        con = Ping.pingecho url.host, CONNECTION_TIMEOUT, 80
        unless con
          warn = true
          msg += " #{CONNECTION_TIMEOUT}秒无法连接上80端口（紧急！）"
        else
          req = Net::HTTP::Get.new(url.path)
          req.add_field 'Host', url.host
          if target.has_key? "bytes_range"
            ma = target["bytes_range"].match(/^(\d+)\.\.(\d+)$/)
            req.set_range ma[1].to_i, ma[2].to_i
          end
          http = Net::HTTP.new(ip, url.port)
  #        http.open_timeout = 1; http.read_timeout = 1; http.set_debug_output $stderr
          begin
            Timeout::timeout(target['timeout']) { res = http.request(req) }
          rescue Timeout::Error
            warn = true
            msg += "#{target['timeout']}秒超时"
            if target.has_key? "bytes_range"
              rate = (req.range.first.end - req.range.first.first) / target['timeout'] / 1024
              msg += " 不足 #{rate}Kbytes/秒"
            end
          end
          case res
          when Net::HTTPSuccess
            # OK
          else
            warn = true
            msg +=" #{@res}"
          end
        end
        if warn
          times = 0
          if File.exists? log
            times = File.read(log).to_i
          end
          times += 1
          msg += " 已"
          if times > 1
            msg += "连续"
          end
          msg += "#{times}次失败"
          puts msg
          if target['warn'] <= times
            alert_im msg
          end
          f = File.new(log, "w")
          f.write(times)
          f.close
        else
          if File.exists? log
            File.delete log
          end
          puts msg + " OK"
        end
#      }
    }
#  }
}
