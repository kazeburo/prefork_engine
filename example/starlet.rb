# -*- coding: utf-8 -*-

# sample Rack handler using PreforkEngine
# This is ruby port of Starlet (https://metacpan.org/pod/Starlet)
#
# ## How to use
# $ gem install pico_http_parser
# $ gem isntall prefork_engine
# $ cat config.ru
# class HelloApp
#   def call(env)
#     [
#       200,
#       { 'Content-Type' => 'text/html' },
#       ['hello world ']
#     ]
#   end
# end
#
# run HelloApp.new
#
# $ rackup -r ./starlet.rb -E production -s Starlet \
#    -O MaxWorkers=5 -O MaxRequestPerChild=1000 -O MinRequestPerChild=800 config.ru
#
# ## LICENSE
# This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
# See http://www.perl.com/perl/misc/Artistic.html

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rubygems'
require 'rack'
require 'stringio'
require 'socket'
require 'rack/utils'
require 'io/nonblock'
require 'prefork_engine'
require 'pico_http_parser'

module Rack
  module Handler
    class Starlet
      DEFAULT_OPTIONS = {
        :Host => '0.0.0.0',
        :Port => 9292,
        :MaxWorkers => 10,
        :Timeout => 300,
        :MaxRequestPerChild => 100,
        :MinRequestPerChild => nil,
        :SpawnInterval => nil,
        :ErrRespawnInterval => nil
      }
      NULLIO  = StringIO.new("").set_encoding('BINARY')

      def self.run(app, options={})
        slf = new(options)
        slf.setup_listener()
        slf.run_worker(app)
      end

      def self.valid_options
        {
          "Host=HOST" => "Hostname to listen on (default: 0.0.0.0)",
          "Port=PORT" => "Port to listen on (default: 9292)",
        }
      end

      def initialize(options={})
        @options = DEFAULT_OPTIONS.merge(options)
        @server = nil
        @_is_tcp = false
        @_using_defer_accept = false
      end

      def setup_listener()
        if ENV["SERVER_STARTER_PORT"] then
          hostport, fd = ENV["SERVER_STARTER_PORT"].split("=",2)
          if m = hostport.match(/(.*):(\d+)/) then
            @options[:Host] = m[0]
            @options[:Port] = m[1].to_i
          else
            @options[:Port] = hostport
          end
          @server = TCPServer.for_fd(fd.to_i)
          @_is_tcp = true if !@server.local_address.unix?
        end

        if @server == nil
          @server = TCPServer.new(@options[:Host], @options[:Port])
          @server.setsockopt(:SOCKET, :REUSEADDR, 1)
          @_is_tcp = true
        end

        if RUBY_PLATFORM.match(/linux/) && @_is_tcp == true then
          begin
            @server.setsockopt(Socket::IPPROTO_TCP, 9, 1)
            @_using_defer_accept = true
          end
        end
      end

      def run_worker(app)
        pm_args = {
          "max_workers" => @options[:MaxWorkers].to_i,
          "trap_signals" => {
            "TERM" => 'TERM',
            "HUP"  => 'TERM',
          },
        }
        if @options[:SpawnInterval] then
          pm_args["trap_signals"]["USR1"] = ["TERM", @options[:SpawnInterval].to_i]
          pm_args["spawn_interval"] = @options[:SpawnInterval].to_i
        end
        if @options[:ErrRespawnInterval] then
          pm_args["err_respawn_interval"] = @options[:ErrRespawnInterval].to_i
        end
        pe = PreforkEngine.new(pm_args)
        while !pe.signal_received.match(/^(TERM|USR1)$/)
          pe.start {
            srand
            self.accept_loop(app)
          }
        end
        pe.wait_all_children
      end

      def _calc_reqs_per_child
        max = @options[:MaxRequestPerChild].to_i
        if min = @options[:MinRequestPerChild] then
          return (max - (max - min.to_i + 1) * rand).to_i
        end
        return max.to_i
      end

      def accept_loop(app)
        @can_exit = true
        @term_received = 0
        proc_req_count = 0

        Signal.trap('TERM') {
          if @can_exit then
            exit!(true)
          end
          @term_received += 1
          if @can_exit || @term_received > 1 then
            exit!(true)
          end
        }
        Signal.trap('PIPE', proc { })
        max_reqs = self._calc_reqs_per_child()
        while proc_req_count < max_reqs
          @can_exit = true
          connection = @server.accept
          begin
            connection.nonblock = true
            peeraddr = nil
            peerport = 0
            if @_is_tcp then
              connection.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
              peer = connection.peeraddr
              peeraddr = peer[2]
              peerport = peer[1].to_s
            end
            proc_req_count += 1
            @_is_deferred_accept = @_using_defer_accept
            env = {
              'SERVER_NAME' => @options[:Host],
              'SERVER_PORT' => @options[:Port].to_s,
              'REMOTE_ADDR' => peeraddr,
              'REMOTE_PORT' => peerport,
              'rack.version' => [0,1],
              'rack.errors' => STDERR,
              'rack.multithread' => false,
              'rack.multiprocess' => false,
              'rack.run_once' => false,
              'rack.url_scheme' => 'http'
            }
            self.handle_connection(env, connection, app)
          ensure
            connection.close
          end
        end
      end
      def handle_connection(env, connection, app)
        buf = ""
        while true
          readed = self.read_timeout(connection)
          if readed == nil then
            next
          end
          @can_exit = false
          buf += readed
          reqlen = PicoHTTPParser.parse_http_request(buf,env)
          if reqlen >= 0 then
            # force donwgrade to 1.0
            env["SERVER_PROTOCOL"] = "HTTP/1.0"
            # handle request
            if (cl = env["CONTENT_LENGTH"].to_i) > 0 then
              buf = buf.unpack('C*').slice(reqlen..-1).pack('C*')
              buffer = StringIO.new("").set_encoding('BINARY')
              while cl > 0
                chunk = ""
                if buf.bytesize > 0 then
                  chunk = buf
                  buf = ""
                else
                  readed = self.read_timeout(connection)
                  if readed == nil then
                    return
                  end
                  chunk += readed
                end
                buffer << chunk
                cl -= chunk.bytesize
              end
              buffer.rewind
              env["rack.input"] = buffer
            else
              env["rack.input"] = NULLIO
            end
            status, header, body = app.call(env)
            res_header = "HTTP/1.0 "+status.to_s+" "+Rack::Utils::HTTP_STATUS_CODES[status]+"\r\nConnection: close\r\n"
            sent_date = false
            sent_server = false
            header.each do |k,vs|
              dk = k.downcase
              if dk == "connection" then
                next
              end
              if dk == "date" then
                sent_date = true
              end
              if dk == "server" then
                sent_server = true
              end
              res_header += k + ": " + vs + "\r\n"
            end
            if !sent_date then
              res_header += "Date: " + Time.now.httpdate + "\r\n"
            end
            if !sent_server then
              res_header += "Server: RubyStarlet\r\n"
            end
            res_header += "\r\n"
            if body.length == 1 && body[0].bytesize < 40960 then
              ret = self.write_all(connection,res_header+body[0])
            else
              ret = self.write_all(connection,res_header)
              body.each do |part|
                self.write_all(connection,part)
              end
            end
            return true
          elsif reqlen == -2 then
            # request is incomplete, do nothing
          else
            # error
            return nil
          end
        end
      end

      def read_timeout(connection)
        if @_is_deferred_accept then
          @_is_deferred_accept = false
        else
          if !IO.select([connection],nil,nil,300) then
            return nil
          end
        end
        while true
          begin
            buf = connection.sysread(4096)
            return buf
          rescue IO::WaitReadable
            # retry
            break
          rescue EOFError
            # closed
            return nil
          end
        end
      end

      def write_timeout(connection, buf)
        while true
          begin
            len = connection.syswrite(buf)
            return len
          rescue IO::WaitReadable
            # retry
            break
          rescue EOFError
            # closed
            return nil
          end
        end
        if !IO.select(nil,[connection],nil,300) then
          return nil
        end
      end

      def write_all(connection, buf)
        off = 0
        while buf.bytesize - off > 0
          ret = self.write_timeout(connection,buf.unpack('C*').slice(off..-1).pack('C*'))
          if ret == nil then
            return nil
          end
          off += ret
        end
        return buf.bytesize
      end

    end
  end
end


