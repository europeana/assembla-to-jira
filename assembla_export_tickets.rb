# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

ITEMS = [
  { name: 'ticket_comments' },
  { name: 'attachments' },
  { name: 'tags' },
  { name: 'ticket_associations' }
].freeze

RELATIONSHIP_NAMES = %w{Parent Child Related Duplicate Sibling Story Subtask Dependent Block}.freeze

PER_PAGE = 100.freeze

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

url_space = "#{ASSEMBLA_API_HOST}/spaces/#{space['id']}"

url_tickets = "#{url_space}/tickets?per_page=#{PER_PAGE}"
page = 0
in_progress = true
tickets = []

while in_progress
  begin
    full_url = "#{url_tickets}&page=#{page}"
    response = RestClient::Request.execute(method: :get, url: full_url, headers: ASSEMBLA_HEADERS)
    count = get_response_count(response)
    puts "GET #{full_url} => OK (#{count})"
    if count.positive?
      JSON.parse(response.body).each do |ticket|
        tickets << ticket
      end
      page += 1
    else
      in_progress = false
    end
  rescue => e
    puts "GET #{url} => NOK (#{e.message})"
    exit
  end
end

@total_tickets = tickets.length

puts "Total tickets: #{@total_tickets}"

create_csv_files(space,  name: 'tickets', results: tickets)

ITEMS.each do |item|
  total = 0
  name = item[:name]
  item[:results] = []
  tickets.each_with_index do |ticket, index|
    ticket[name] = get_ticket_attr(space['id'], ticket['number'], name, { counter: index+1, total: @total_tickets})
    ticket[name].each do |result|
      item[:results] << result
    end
    total += ticket[name].length
    if index == @total_tickets - 1
      puts "Total #{name}: #{total}" if index == @total_tickets - 1
      break
    end
  end
end

dirname = get_output_dirname(space, 'assembla')

ITEMS.each do |item|
  name = item[:name]
  name = (name.match?(/^ticket_/) ? '' : 'ticket_') + name
  create_csv_files(space,  name: name, results: item[:results])
end
