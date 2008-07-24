#!/usr/local/bin/ruby

require "resolv"
require "socket"
require "net/http"
require "uri"
require 'timeout'

require 'prepend'

def alert_im(msg)
  puts msg
  url = URI.parse("http://api.fanfou.com/statuses/update.xml")
  req = Net::HTTP::Post.new(url.path)
  req.basic_auth @config['fanfou']['username'], @config['fanfou']['password']
  req.set_form_data({ 'status' => msg }, ';')
  res = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
end

@label = '未知'
# 设置已知宿主的名称和 dns
if @config["hosts"].has_key? Socket.gethostname
  host = @config["hosts"][Socket.gethostname]
  @label = host["label"]
  @dns = host["dns"]
end
@config["targets"].each {|target|
#  Thread.new {
    if @config['hosts'].has_key? 'skip_targets'
      @config['hosts']['skip_targets'].each {|u|
        if u == target['url']
          next
        end
      }
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
      alert_im "DNS解析超过#{RESOLV_TIMEOUT}秒 @#{@label}"
    end
    ips.each {|ip|
#      Thread.new {
        msg = "[#{Time.now.strftime('%H:%M:%S')}] #{url.host}:#{ip} @#{@label} "
        req = Net::HTTP::Get.new(url.path)
        req.add_field 'Host', url.host
        if target.has_key? "bytes_range"
          ma = target["bytes_range"].match(/^(\d+)\.\.(\d+)$/)
          req.set_range ma[1].to_i, ma[2].to_i
        end
        warn = false
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
        if warn
          alert_im msg
        else
          puts msg + " OK"
        end
#      }
    }
#  }
}
