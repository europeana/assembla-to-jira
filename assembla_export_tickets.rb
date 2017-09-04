# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

ITEMS = [
  { name: 'ticket_comments' },
  { name: 'attachments' },
  { name: 'tags', ticket_id: true },
  { name: 'ticket_associations', relationship: true }
].freeze

# See: http://api-docs.assembla.cc/content/ref/ticket_associations_fields.html
# 0 - Parent (ticket2 is parent of ticket1 and ticket1 is child of ticket2)
# 1 - Child  (ticket2 is child of ticket1 and ticket2 is parent of ticket1)
# 2 - Related (ticket2 is related to ticket1)
# 3 - Duplicate (ticket2 is duplication of ticket1)
# 4 - Sibling (ticket2 is sibling of ticket1)
# 5 - Story (ticket2 is story and ticket1 is subtask of the story)
# 6 - Subtask (ticket2 is subtask of a story and ticket1 is the story)
# 7 - Dependent (ticket2 depends on ticket1)
# 8 - Block (ticket2 blocks ticket1)
RELATIONSHIPS = %w{parent child related duplicate sibling story subtask dependent block}.freeze

def get_ticket_attr(space_id, ticket_number, attr, opts)
  results = []
  response = http_request("#{ASSEMBLA_API_HOST}/spaces/#{space_id}/tickets/#{ticket_number}/#{attr}", opts)
  count = get_response_count(response)
  if count.positive?
    json = JSON.parse(response.body)
    json.each do |result|
      results << result
    end
  end
  results
end

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')

tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
tickets = csv_to_array(tickets_assembla_csv)

# @total_tickets = @debug && tickets.length > 100 ? 100 : tickets.length
@total_tickets = tickets.length

puts "Total tickets: #{@total_tickets}"

create_csv_files(space,  name: 'tickets', results: tickets)

ITEMS.each do |item|
  total = 0
  name = item[:name]
  item[:results] = []
  tickets.each_with_index do |ticket, index|
    ticket[name] = get_ticket_attr(space['id'], ticket['number'], name, counter: index + 1, total: @total_tickets, continue_onerror: true)
    ticket[name].each do |result|
      result = result.merge(ticket_id: ticket['number']) if item[:ticket_id]
      if item[:relationship]
        rid = result['relationship']
        if rid
          rname = rid < RELATIONSHIPS.length ? RELATIONSHIPS[rid] : "unknown (#{rid})"
          result = result.merge(relationship_name: rname)
        end
      end
      item[:results] << result
    end
    total += ticket[name].length
    if index == @total_tickets - 1
      puts "Total #{name}: #{total}" if index == @total_tickets - 1
      break
    end
  end
end

ITEMS.each do |item|
  name = item[:name]
  name = (name.match?(/^ticket_/) ? '' : 'ticket_') + name
  create_csv_files(space,  name: name, results: item[:results])
end
