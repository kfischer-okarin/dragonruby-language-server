class LanguageServer
  class UnsupportedMethodError < StandardError; end

  class << self
    # textDocument/didOpen -> handle_text_document_did_open
    def handler_method_name(jsonrpg_method)
      result_parts = ['handle_']
      jsonrpg_method.chars.each do |char|
        result_parts << case char
                        when ('A'..'Z')
                          "_#{char.downcase}"
                        when '/'
                          '_'
                        else
                          char
                        end
      end

      result_parts.join
    end
  end

  attr_accessor :args

  def initialize
    @text_document_store = nil
  end

  def process_request(request)
    method = self.class.handler_method_name(request['method'])
    raise UnsupportedMethodError unless respond_to?(method)

    send(method, request)
  end

  def process_notification(notification)
    method = self.class.handler_method_name(notification['method'])
    return unless respond_to?(method) # Ignore unsupported notifications

    send(method, notification)
  end

  private

  def handle_initialize(message)
    client_capabilities = message['params']['capabilities']

    @text_document_store = TextDocumentStore.build(client_capabilities['textDocument']['synchronization'])
    server_capabilities = {
      textDocumentSync: @text_document_store.text_document_sync_options
    }

    {
      capabilities: server_capabilities,
      serverInfo: { name: 'DragonRuby built-in Language Server', version: $gtk.version }
    }
  end

  def handle_text_document_did_open(message)
    @text_document_store.handle_text_document_did_open(message['params'])
  end

  def handle_text_document_did_change(message)
    @text_document_store.handle_text_document_did_change(message['params'])
  end
end

class LanguageServer
  class TextDocumentStore
    def self.build(client_capabilities)
      new(client_capabilities)
    end

    def initialize(client_capabilities)
      # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentClientCapabilities
      @client_capabilities = client_capabilities
      @documents = {}
    end

    # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentSyncOptions
    def text_document_sync_options
      {
        openClose: true,
        change: 2 # Incremental
      }
    end

    def document_lines(uri)
      @documents[uri]
    end

    def store_text_document(uri, text)
      @documents[uri] = to_lines(text)
    end

    def line_at_position(text_document_position_params)
      uri = text_document_position_params['textDocument']['uri']
      line = text_document_position_params['position']['line']
      @documents[uri][line]
    end

    def char_at_position(text_document_position_params)
      line = line_at_position(text_document_position_params)
      line[text_document_position_params['position']['character']]
    end

    def handle_text_document_did_open(params)
      document = params['textDocument']
      store_text_document(document['uri'], document['text'])
    end

    def handle_text_document_did_change(params)
      uri = params['textDocument']['uri']
      document = @documents[uri]
      return unless document

      params['contentChanges'].each do |change|
        updated_lines = to_lines(change['text'])
        range = change['range']

        if range
          first_changed_line_index = range['start']['line']
          last_changed_line_index = range['end']['line']

          # Merge with unchanged part of the first line
          first_changed_line = document[first_changed_line_index]
          part_before_change = first_changed_line[0...range['start']['character']]
          # Inserting might have added newlines so we need to convert to lines
          new_initial_lines = to_lines(part_before_change + updated_lines[0])
          updated_lines[0..0] = new_initial_lines

          # Merge with unchanged part of the last line
          last_changed_line = document[last_changed_line_index]
          part_after_change = last_changed_line[range['end']['character']..]
          # Inserting might have added newlines so we need to convert to lines
          new_last_lines = to_lines(updated_lines[-1] + part_after_change)
          updated_lines[-1..-1] = new_last_lines

          document[first_changed_line_index..last_changed_line_index] = updated_lines
        else # Full text change
          @documents[uri] = updated_lines
        end
      end
    end

    private

    def to_lines(string)
      result = string.lines
      result << '' if result.empty? # Because empty string will produce an empty array
      result
    end
  end
end
