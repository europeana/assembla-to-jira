# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

ITEMS = [
  { name: 'ticket_comments', ticket_id: false },
  { name: 'attachments', ticket_id: false },
  { name: 'tags', ticket_id: true },
  { name: 'ticket_associations', ticket_id: false }
].freeze

RELATIONSHIP_NAMES = %w{parent child related duplicate sibling story subtask dependent block}.freeze

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

@total_tickets = tickets.length

puts "Total tickets: #{@total_tickets}"

create_csv_files(space,  name: 'tickets', results: tickets)

ITEMS.each do |item|
  total = 0
  name = item[:name]
  item[:results] = []
  tickets.each_with_index do |ticket, index|
    ticket[name] = get_ticket_attr(space['id'], ticket['number'], name, counter: index+1, total: @total_tickets)
    ticket[name].each do |result|
      result = result.merge(ticket_id: ticket['number']) if item[:ticket_id]
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
