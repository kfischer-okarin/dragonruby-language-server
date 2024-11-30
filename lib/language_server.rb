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
    @completion_provider = UnsupportedProvider.new
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

    if client_capabilities.dig('textDocument', 'completion')
      @completion_provider = CompletionProvider.build(
        client_capabilities['textDocument']['completion'],
        text_document_store: @text_document_store
      )
      server_capabilities['completionProvider'] = @completion_provider.capabilities
    end

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

  def handle_text_document_completion(message)
    @completion_provider.handle_text_document_completion(message['params'])
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

class LanguageServer
  class UnsupportedProvider
    def method_missing(*)
      raise UnsupportedMethodError
    end
  end
end

class LanguageServer
  class CompletionProvider
    def self.build(client_capabilities, text_document_store:)
      new(client_capabilities, text_document_store: text_document_store)
    end

    attr_reader :capabilities

    def initialize(client_capabilities, text_document_store:)
      # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionClientCapabilities
      @client_capabilities = client_capabilities
      @text_document_store = text_document_store
      # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionOptions
      @capabilities = {
        triggerCharacters: ['.']
      }

      # TODO: Resolve support
      # - Documentation
      #   - Read from local documentation database file with short markdown docs
      #   - Check @client_capabilities['completionItem']['resolveSupport'].include?('documentation')
      # - Detail
      #   - Current value of args....
      #   - Check @client_capabilities['completionItem']['resolveSupport'].include?('detail')
    end

    def handle_text_document_completion(params)
      uri = params['textDocument']['uri']
      document_lines = @text_document_store.document_lines(uri)
      current_line = document_lines[params['position']['line']]
      character_index = params['position']['character']

      identifier_start_index = character_index
      puts "current_line: '#{current_line}'"
      puts '              ' + ' ' * identifier_start_index + '^'
      while identifier_start_index >= 0
        break if current_line[identifier_start_index - 1] == ' '

        identifier_start_index -= 1
      end
      return [] if identifier_start_index.negative?

      identifier = current_line[identifier_start_index..character_index]
      identifier = "$#{identifier}" if identifier.start_with?('args')
      puts "identifier: '#{identifier}'"
      if identifier.start_with?('$')
        period_index = identifier.rindex('.')
        object_part = identifier[0...period_index]
        completion_prefix = identifier[period_index + 1..].strip
        object = eval(object_part)
        object.autocomplete_methods.select { |method|
          method.start_with?(completion_prefix)
        }.map { |method|
          {
            label: method.to_s,
            kind: 2 # Method
          }
        }
      else
        []
      end
    end
  end
end
