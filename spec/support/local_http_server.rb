# frozen_string_literal: true

require "socket"
require "uri"

# Minimal single-threaded HTTP file server bound to 127.0.0.1.
#
# Lets cache-download specs exercise the REAL Net::HTTP download path
# against a real socket — no external network access and no test
# doubles. GET requests are served from a document root; anything else
# (missing path, non-GET) is a 404, which specs use to drive
# mirror-fallback behavior.
class LocalHttpServer
  # @return [String] base URL, e.g. "http://127.0.0.1:54321"
  attr_reader :base_url

  # @param root [String] directory whose files are served by path
  def initialize(root:)
    @root = File.expand_path(root)
    @server = TCPServer.new("127.0.0.1", 0)
    @base_url = "http://127.0.0.1:#{@server.addr[1]}"
    @thread = Thread.new { serve_loop }
  end

  # Stop accepting connections. In-flight responses complete because
  # they are written before accept is called again.
  def stop
    @server.close
    @thread.join(1)
    nil
  end

  private

  def serve_loop
    loop do
      begin
        client = @server.accept
      rescue StandardError
        break # server closed
      end

      begin
        handle(client)
      rescue StandardError
        nil
      end
    end
  end

  def handle(client)
    request_line = client.gets
    return unless request_line

    method, path, = request_line.split(" ")
    drain_headers(client)

    file = resolve_path(path)
    if method == "GET" && file && File.file?(file)
      respond(client, "200 OK", File.binread(file))
    else
      respond(client, "404 Not Found", "not found: #{path}")
    end
  ensure
    client.close
  end

  def drain_headers(client)
    while (line = client.gets)
      break if line.strip.empty?
    end
  end

  def respond(client, status, body)
    client.print(
      "HTTP/1.1 #{status}\r\n" \
      "Content-Length: #{body.bytesize}\r\n" \
      "Connection: close\r\n" \
      "\r\n"
    )
    client.write(body)
  end

  # Map a request path to a file under the root, rejecting traversal.
  def resolve_path(path)
    relative = path.to_s.split("?").first.to_s
    return nil unless relative.start_with?("/")

    decoded = begin
      URI.decode_www_form_component(relative)
    rescue StandardError
      relative
    end
    candidate = File.expand_path(File.join(@root, decoded))
    candidate.start_with?(@root + File::SEPARATOR) ? candidate : nil
  end
end
