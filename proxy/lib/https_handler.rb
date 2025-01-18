class HTTPSHandler
  BLOCKED_DOMAINS = [
    "www.youtube.com",
    "i.ytimg.com",
    "yt3.ggpht.com",
    "rr2---sn-j5caxoxu-i2o6.googlevideo.com",
    "fonts.googleapis.com",
    "fonts.gstatic.com",
    "play.google.com",
    "history.google.com",
    "encrypted-tbn0.gstatic.com",
    "www.gstatic.com",
    "jnn-pa.googleapis.com",
    "googleads.g.doubleclick.net",
    "static.doubleclick.net",
    "d.joinhoney.com",
    "cdn.honey.io",
    "mobile.events.data.microsoft.com"
  ]

  def initialize(logger, mutex)
    @logger = logger
    @mutex = mutex
  end

  def handle(client, first_line, headers, metrics)
    host, port = parse_destination(first_line)
    update_metrics(metrics, host, port)

    if blocked?(host)
      handle_blocked_request(client, metrics)
      return
    end

    log_connection_details(metrics, headers)
    establish_connection(client, metrics)
  end

  private

  def parse_destination(first_line)
    host, port = first_line.split[1].split(":")
    [host, port || "443"]
  end

  def update_metrics(metrics, host, port)
    metrics.host = host
    metrics.port = port
  end

  def blocked?(host)
    BLOCKED_DOMAINS&.include?(host)
  end

  def handle_blocked_request(client, metrics)
    @logger.info("[#{metrics.request_id}] Blocked HTTPS connection to #{metrics.host}:#{metrics.port}")
    client.write("HTTP/1.1 403 Forbidden\r\n\r\n")
  end

  def log_connection_details(metrics, headers)
    @logger.info("[#{metrics.request_id}] Initiating HTTPS connection to #{metrics.host}:#{metrics.port}")
    @logger.info("[#{metrics.request_id}] TLS Server Name: #{metrics.host}")

    if parsed_headers = parse_headers(headers)
      @logger.info("[#{metrics.request_id}] Proxy-Connection: #{parsed_headers["proxy-connection"]}")
      @logger.info("[#{metrics.request_id}] User-Agent: #{parsed_headers["user-agent"]}")
    end
  end

  def parse_headers(headers)
    headers.each_with_object({}) do |line, hash|
      if line =~ /^([^:]+):\s*(.+)/
        hash[$1.downcase] = $2
      end
    end
  end

  def establish_connection(client, metrics)
    remote = nil
    begin
      remote = create_remote_connection(client, metrics)
      handle_bidirectional_transfer(client, remote, metrics)
    rescue => e
      handle_connection_error(e, metrics)
    ensure
      begin
        remote&.close
      rescue
        nil
      end
    end
  end

  def create_remote_connection(client, metrics)
    remote = TCPSocket.new(metrics.host, metrics.port)
    client.write("HTTP/1.1 200 Connection Established\r\n\r\n")
    @logger.info("[#{metrics.request_id}] Established HTTPS connection to #{metrics.host}:#{metrics.port}")
    remote
  end

  def handle_bidirectional_transfer(client, remote, metrics)
    should_stop = false
    threads = []

    threads << create_client_to_remote_thread(client, remote, metrics, should_stop)
    threads << create_remote_to_client_thread(client, remote, metrics, should_stop)

    threads.each(&:join)
  end

  def create_client_to_remote_thread(client, remote, metrics, should_stop)
    Thread.new do
      transfer_data(
        source: client,
        destination: remote,
        metrics: metrics,
        direction: "Client -> Server",
        should_stop: should_stop
      )
    end
  end

  def create_remote_to_client_thread(client, remote, metrics, should_stop)
    Thread.new do
      transfer_data(
        source: remote,
        destination: client,
        metrics: metrics,
        direction: "Server -> Client",
        should_stop: should_stop
      )
    end
  end

  def transfer_data(source:, destination:, metrics:, direction:, should_stop:)
    buffer = String.new(capacity: 16384)
    loop do
      break if should_stop

      begin
        bytes_read = source.read_nonblock(16384, buffer)
        update_bytes_count(metrics, bytes_read.bytesize, direction)
        destination.write(bytes_read)
        log_data_transfer(metrics, direction, bytes_read.bytesize)
      rescue IO::WaitReadable
        IO.select([source])
        retry
      rescue EOFError
        break
      end
    end
  rescue IOError, Errno::EPIPE, Errno::ECONNRESET => e
    @logger.debug("[#{metrics.request_id}] #{direction} connection closed: #{e.message}")
  rescue => e
    @logger.error("[#{metrics.request_id}] Error in #{direction} thread: #{e.message}")
  ensure
    should_stop = true
  end

  def update_bytes_count(metrics, bytes, direction)
    @mutex.synchronize do
      if direction.start_with?("Client")
        metrics.client_bytes += bytes
      else
        metrics.server_bytes += bytes
      end
    end
  end

  def log_data_transfer(metrics, direction, bytes)
    @logger.debug("[#{metrics.request_id}] #{direction}: #{bytes} bytes")
  end

  def handle_connection_error(error, metrics)
    @logger.error("[#{metrics.request_id}] Error in HTTPS connection: #{error.message}")
    @logger.error("[#{metrics.request_id}] #{error.backtrace.join("\n")}")
  end
end
