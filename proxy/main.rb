require "socket"
require "openssl"
require "logger"
require "uri"
require "time"

Dir[File.join(__dir__, "lib", "*.rb")].each { |file| require file }

class Server
  def initialize(listen_port, logger)
    @listen_port = listen_port
    @logger = logger
    @mutex = Mutex.new
  end

  def start
    server = TCPServer.new(@listen_port)
    @logger.info("Proxy listening on port #{@listen_port}")

    loop do
      Thread.start(server.accept) do |client|
        handle_client(client)
      end
    end
  end

  private

  def parse_headers(raw_headers)
    headers = {}
    raw_headers.each do |line|
      if line =~ /^([^:]+):\s*(.+)/
        headers[$1.downcase] = $2
      end
    end
    headers
  end

  def handle_client(client)
    metrics = ServerLogger.new

    # Get client IP and port
    peer_address = client.remote_address
    metrics.client_ip = peer_address.ip_address
    metrics.client_port = peer_address.ip_port

    @logger.info("[#{metrics.request_id}] New connection from #{metrics.client_ip}:#{metrics.client_port}")

    # Block based on IP Address or Port

    first_line = client.gets
    return unless first_line

    @logger.info("[#{metrics.request_id}] New connection started at #{metrics.start_time}")
    @logger.info("[#{metrics.request_id}] Received request: #{first_line.strip}")

    # Parse first line
    parts = first_line.strip.split
    metrics.method = parts[0]
    metrics.path = parts[1]
    metrics.protocol = parts[2]

    headers = []
    while (line = client.gets)
      break if line == "\r\n"
      headers << line.strip
      @logger.debug("[#{metrics.request_id}] Header: #{line.strip}")
    end

    parsed_headers = parse_headers(headers)
    metrics.request_headers = parsed_headers
    metrics.user_agent = parsed_headers["user-agent"]
    metrics.content_type = parsed_headers["content-type"]
    metrics.content_length = parsed_headers["content-length"]

    if first_line.start_with?("CONNECT")
      HTTPSHandler.new(@logger, @mutex).handle(client, first_line, headers, metrics)
    else
      HTTPHandler.new(@logger, @mutex).handle(client, first_line, headers, metrics)
    end

    metrics.end_time = Time.now
    metrics.log_summary(@logger)
  rescue => e
    @logger.error("[#{metrics&.request_id}] Error in handle_client: #{e.message}")
    @logger.error("[#{metrics&.request_id}] #{e.backtrace.join("\n")}")
  ensure
    begin
      client.close
    rescue
      nil
    end
  end
end

# Set up logging with timestamp format
logger = Logger.new(STDOUT)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime("%Y-%m-%d %H:%M:%S.%L")} [#{severity}] #{msg}\n"
end

# Create and start the proxy
proxy = Server.new(443, logger)
proxy.start
