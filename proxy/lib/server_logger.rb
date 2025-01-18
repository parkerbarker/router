class ServerLogger
  attr_accessor :start_time, :end_time, :client_bytes, :server_bytes,
    :request_headers, :host, :port, :method, :path, :protocol,
    :content_type, :content_length, :user_agent, :request_id,
    :client_ip, :client_port

  def initialize
    @start_time = Time.now
    @client_bytes = 0
    @server_bytes = 0
    @request_id = generate_request_id
  end

  def duration
    (@end_time - @start_time).round(3)
  end

  def log_summary(logger)
    logger.info("[#{@request_id}] Connection Summary:")
    logger.info("[#{@request_id}] Duration: #{duration}s")
    logger.info("[#{@request_id}] Client IP: #{@client_ip}")
    logger.info("[#{@request_id}] Client Port: #{@client_port}")
    logger.info("[#{@request_id}] Client sent: #{@client_bytes} bytes")
    logger.info("[#{@request_id}] Server sent: #{@server_bytes} bytes")
    logger.info("[#{@request_id}] Host: #{@host}:#{@port}")
    logger.info("[#{@request_id}] Method: #{@method}")
    logger.info("[#{@request_id}] Path: #{@path}")
    logger.info("[#{@request_id}] Protocol: #{@protocol}")
    logger.info("[#{@request_id}] Content-Type: #{@content_type}")
    logger.info("[#{@request_id}] Content-Length: #{@content_length}")
    logger.info("[#{@request_id}] User-Agent: #{@user_agent}")
  end

  private

  def generate_request_id
    "REQ-#{Time.now.to_i}-#{rand(1000000)}"
  end
end
