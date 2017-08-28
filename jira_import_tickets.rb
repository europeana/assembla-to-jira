# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'

@jira_tickets = []
@fields = []
@assembla = nil

def get_fields()
  url = "#{JIRA_API_HOST}/field"
  result = []
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    puts "POST #{url} => (#{result.length})"
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
  result
end

def create_ticket(ticket)
  url = "#{JIRA_API_HOST}/issue"
  payload = {
    # "update": {},
    # "fields": {
    #   "project": {
    #     "id": "10000"
    #   },
    #   "summary": "something's wrong",
    #   "issuetype": {
    #     "id": "10000"
    #   },
    #   "assignee": {
    #     "name": "homer"
    #   },
    #   "reporter": {
    #     "name": "smithers"
    #   },
    #   "priority": {
    #     "id": "20000"
    #   },
    #   "labels": [
    #     "assembla"
    #   ],
    #   "description": ticket['description'],
    #   "duedate": "2011-03-11",
    #   "customfield_10007": ticket['number'],
    #   "customfield_30000": [
    #     "10000",
    #     "10002"
    #   ],
    #   "customfield_80000": {
    #     "value": "red"
    #   },
    #   "customfield_20000": "06/Jul/11 3:25 PM",
    #   "customfield_40000": "this is a text field",
    #   "customfield_70000": [
    #     "jira-administrators",
    #     "jira-software-users"
    #   ],
    #   "customfield_60000": "jira-software-users",
    #   "customfield_50000": "this is a text area. big text.",
    #   "customfield_10000": "09/Jun/81"
    # }
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    puts "POST #{url} => #{body.to_json}"
    @jira_users << body
    result = true
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
end

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space)
tickets_csv = "#{dirname}/tickets.csv"
jira_tickets_csv = "#{dirname}/jira-tickets.csv"

tickets = csv_to_array(tickets_csv)

@fields = get_fields

@assembla = @fields.find{ |field| field['name'] == 'Assembla' }

if @assembla
  puts "Assembla id = '#{@assembla['id']}'"
else
  puts "Assembla custom field is missing, please define in Jira"
  exit
end

exit

@fields.each do |field|
  puts "id=#{field['id']} name='#{field['name']}' #{field['custom']}"
end

tickets.each do |ticket|
  create_ticket(ticket)
end

write_csv_file(jira_tickets_csv, @jira_tickets)