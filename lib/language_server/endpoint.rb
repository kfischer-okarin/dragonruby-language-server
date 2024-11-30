module LSPEndpoint
  def routes
    super + [
      {
        match_criteria: { method: :post, uri: '/dragon/lsp/' },
        handler: :post_lsp
      }
    ]
  end

  def post_lsp(args, request)
    @language_server ||= LanguageServer.new
    @language_server.args = args

    message = $gtk.parse_json(request.body)
    unless message
      respond_with_jsonrpc(
        request,
        error: { code: -32_700, message: 'Invalid JSON' }
      )
      return
    end

    if message['id'] # Request
      begin
        response = @language_server.process_request(message)
        respond_with_jsonrpc(
          request,
          id: message['id'],
          result: response
        )
      rescue LanguageServer::UnsupportedMethodError
        respond_with_jsonrpc(
          request,
          id: message['id'],
          error: { code: -32_601, message: 'Unsupported method' }
        )
      end
    else # Notification
      @language_server.process_notification(message)
      request.respond 204, nil, {}
    end
  end

  def respond_with_jsonrpc(request, body)
    request.respond 200,
                    to_json(
                      jsonrpc: '2.0',
                      **body
                    ),
                    { 'Content-Type' => 'application/json' }
  end

  # Only handling primitive types
  def to_json(obj)
    case obj
    when Hash
      key_value_pairs = obj.map { |k, v| "#{k.to_s.inspect}:#{to_json(v)}" }
      "{#{key_value_pairs.join(',')}}"
    when Array
      items = obj.map { |v| to_json(v) }
      "[#{items.join(',')}]"
    when String
      obj.inspect
    when NilClass
      'null'
    else
      obj.to_s
    end
  end
end

GTK::Api.prepend(LSPEndpoint) unless GTK::Api.include?(LSPEndpoint)
