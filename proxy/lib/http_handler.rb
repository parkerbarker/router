class HTTPHandler
  def initialize(logger, mutex)
    @logger = logger
    @mutex = mutex
  end

  def handle(client, first_line, headers, metrics)
    uri = URI.parse(first_line.split[1])
    metrics.host = uri.host
    metrics.port = uri.port || 80

    remote = TCPSocket.new(metrics.host, metrics.port)

    # Forward the initial request and headers
    remote.write(first_line)
    headers.each { |header| remote.write(header + "\r\n") }
    remote.write("\r\n")

    @logger.info("[#{metrics.request_id}] Established HTTP connection to #{metrics.host}:#{metrics.port}")

    forward_data(client, remote, metrics)
  rescue => e
    @logger.error("[#{metrics.request_id}] Error in HTTP connection: #{e.message}")
  ensure
    begin
      remote&.close
    rescue
      nil
    end
  end

  def forward_data(client, remote, metrics)
    loop do
      ready = IO.select([client, remote])

      ready[0].each do |socket|
        data = socket.recv(16384)

        nextif data.empty?

        if socket == client
          @mutex.synchronize { metrics.client_bytes += data.bytesize }
          @logger.debug("[#{metrics.request_id}] Client -> Server: #{data.bytesize} bytes")
          remote.write(data)
        else
          @mutex.synchronize { metrics.server_bytes += data.bytesize }
          @logger.debug("[#{metrics.request_id}] Server -> Client: #{data.bytesize} bytes")
          client.write(data)
        end
      rescue => e
        @logger.error("[#{metrics.request_id}] Error forwarding data: #{e.message}")
        next
      end
    end
  rescue => e
    @logger.error("[#{metrics.request_id}] Error in data forwarding: #{e.message}")
  end
end
