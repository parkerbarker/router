# Logs

Ingest and analyze logs captured from suricata.

## Importing Suricata Logs into Elasticsearch

Here is an example of how to import `eve.json` logs from Suricata into Elasticsearch using Ruby:

```ruby
require 'json'
require 'elasticsearch'

# Initialize the Elasticsearch client
client = Elasticsearch::Client.new log: true

# Path to the eve.json file
file_path = '/Users/cameronbarker/Desktop/eve-01-09-25.json'

# Read and parse the eve.json file
File.open(file_path, 'r') do |file|
  file.each_line do |line|
    begin
      log_entry = JSON.parse(line)
      client.index index: 'suricata-logs', body: log_entry
    rescue JSON::ParserError => e
      puts "Failed to parse line: #{e.message}"
    end
  end
end

puts "Logs have been successfully imported into Elasticsearch."
```

## Schema for `suricata-logs` Index

Here is an example of the schema for the `suricata-logs` index in Elasticsearch:

```json
{
  "mappings": {
    "properties": {
      "timestamp": { "type": "date" },
      "flow_id": { "type": "keyword" },
      "in_iface": { "type": "keyword" },
      "event_type": { "type": "keyword" },
      "src_ip": { "type": "ip" },
      "src_port": { "type": "integer" },
      "dest_ip": { "type": "ip" },
      "dest_port": { "type": "integer" },
      "proto": { "type": "keyword" },
      "alert": {
        "properties": {
          "action": { "type": "keyword" },
          "gid": { "type": "integer" },
          "signature_id": { "type": "integer" },
          "rev": { "type": "integer" },
          "signature": { "type": "text" },
          "category": { "type": "keyword" },
          "severity": { "type": "integer" }
        }
      },
      "http": {
        "properties": {
          "hostname": { "type": "keyword" },
          "url": { "type": "text" },
          "http_user_agent": { "type": "text" },
          "http_content_type": { "type": "keyword" },
          "http_method": { "type": "keyword" },
          "protocol": { "type": "keyword" },
          "status": { "type": "integer" },
          "length": { "type": "integer" }
        }
      },
      "dns": {
        "properties": {
          "type": { "type": "keyword" },
          "id": { "type": "integer" },
          "rrname": { "type": "keyword" },
          "rrtype": { "type": "keyword" },
          "rcode": { "type": "keyword" }
        }
      }
    }
  }
}
```

## Installing Elasticsearch on a Mac

To install Elasticsearch on a Mac, follow these steps:

1. Use Homebrew to install Elasticsearch:
    ```bash
    brew tap elastic/tap
    brew install elastic/tap/elasticsearch-full
    ```

2. Start Elasticsearch:
    ```bash
    ES_JAVA_HOME=/usr/local/opt/openjdk elasticsearch
    ```

3. Verify that Elasticsearch is running by opening `http://localhost:9200` in your web browser. You should see a JSON response with information about your Elasticsearch cluster.
```

