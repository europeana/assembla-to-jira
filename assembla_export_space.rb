# frozen_string_literal: true

load './lib/common.rb'

ITEMS = [
  { name: 'space_tools' },
  { name: 'users' },
  { name: 'user_roles' },
  { name: 'tags' },
  { name: 'milestones' },
  { name: 'tickets/statuses' },
  { name: 'tickets/custom_fields' },
  { name: 'documents', q: 'per_page=100' },
  { name: 'wiki_pages', q: 'per_page=10' },
  { name: 'tickets', q: 'report=0&sort_by=number&per_page=100' }
].freeze

export_items(ITEMS)
