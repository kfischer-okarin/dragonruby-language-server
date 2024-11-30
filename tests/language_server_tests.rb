def test_text_document_store_open(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})

  store.handle_text_document_did_open(
    'textDocument' => {
      'uri' => 'file:///test.txt',
      'text' => "Hello, world!\nThis is a test.\n"
    }
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Hello, world!\n", "This is a test.\n"]
end

def test_text_document_store_change_single_line(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello, world!\nThis is a test.\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 0 },
          'end' => { 'line' => 0, 'character' => 5 }
        },
        'text' => 'Goodbye'
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Goodbye, world!\n", "This is a test.\n"]
end

def test_text_document_change_multiple_lines(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello, world!\nThis is a test.\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 0 },
          'end' => { 'line' => 1, 'character' => 4 }
        },
        'text' => 'Bob'
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Bob is a test.\n"]
end

def test_text_document_store_change_remove_newline(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello\nTest\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 5 },
          'end' => { 'line' => 1, 'character' => 0 }
        },
        'text' => ''
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["HelloTest\n"]
end

def test_text_document_store_change_add_lines(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello, world!\nThis is a test.\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 0 },
          'end' => { 'line' => 0, 'character' => 0 }
        },
        'text' => "Goodbye, world!\n"
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Goodbye, world!\n", "Hello, world!\n", "This is a test.\n"]
end

def test_text_document_store_change_insert_newline_at_end(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello\nTest\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 1, 'character' => 4 },
          'end' => { 'line' => 1, 'character' => 4 }
        },
        'text' => "\n"
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Hello\n", "Test\n", "\n"]
end

def test_text_document_store_change_merge_with_previous_line(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello\nTest\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 5 },
          'end' => { 'line' => 1, 'character' => 0 }
        },
        'text' => ''
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["HelloTest\n"]
end

def test_text_document_store_change_delete_line(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello\nTest\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'range' => {
          'start' => { 'line' => 0, 'character' => 0 },
          'end' => { 'line' => 0, 'character' => 5 }
        },
        'text' => ''
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["\n", "Test\n"]
end

def test_text_document_store_change_full_replace(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello\nTest\n"
  )

  store.handle_text_document_did_change(
    'textDocument' => {
      'uri' => 'file:///test.txt'
    },
    'contentChanges' => [
      {
        'text' => "Goodbye, world!\n"
      }
    ]
  )

  assert.equal! store.document_lines('file:///test.txt'), ["Goodbye, world!\n"]
end

def test_text_document_store_line_at_position(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello, world!\nThis is a test.\n"
  )
  position = {
    'textDocument' => { 'uri' => 'file:///test.txt' },
    'position' => { 'line' => 1, 'character' => 0 }
  }

  assert.equal! store.line_at_position(position), "This is a test.\n"
end

def test_text_document_store_char_at_position(_args, assert)
  store = LanguageServer::TextDocumentStore.build({})
  store.store_text_document(
    'file:///test.txt',
    "Hello, world!\nThis is a test.\n"
  )
  position = {
    'textDocument' => { 'uri' => 'file:///test.txt' },
    'position' => { 'line' => 1, 'character' => 5 }
  }

  assert.equal! store.char_at_position(position), 'i'
end
