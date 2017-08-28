# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' | TEST' : '')

@jira_tickets = []

# Custom fields:
# -------------
# 10000 Development
# 10001 Team
# 10002 Organizations
# 10003 Epic Name
# 10004 Epic Status
# 10005 Epic Color
# 10006 Epic Link
# 10007 Parent Link
# 10100 [CHART] Date of First Response
# 10101 [CHART] Time in Status
# 10102 Approvals
# 10103 Sprint
# 10104 Rank
# 10105 Story Points
# 10108 Test sessions
# 10109 Raised during
# 10200 Testing status
# 10300 Capture for JIRA user agent
# 10301 Capture for JIRA browser
# 10302 Capture for JIRA operating system
# 10303 Capture for JIRA URL
# 10304 Capture for JIRA screen resolution
# 10305 Capture for JIRA jQuery version
# 10400 Assembla

def get_field(name)
  @fields.find{ |field| field['name'] == name }
end

def create_ticket(ticket)
  payload = {
    "update": {},
    "fields": {
       "project": {
         "id": @project['id']
       }
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
    }
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: URL_JIRA_ISSUES, payload: payload, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    puts "POST #{URL_JIRA_ISSUES} => OK #{body.to_json}"
    @jira_tickets << body
    result = true
  rescue => e
    puts "POST #{URL_JIRA_ISSUES} => NOK (#{e.message})"
  end
end

# Ensure that the project exists, otherwise ask the user to create it first.
@project = get_project_by_name(JIRA_PROJECT_NAME)

if @project
  puts "Found project '#{JIRA_PROJECT_NAME}' id='#{@project['id']}' key='#{@project['key']}'"
else
  puts "You must first create a Jira project called '#{JIRA_PROJECT_NAME}' in order to continue"
  exit
end

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space)
tickets_csv = "#{dirname}/tickets.csv"
jira_tickets_csv = "#{dirname}/jira-tickets.csv"

tickets = csv_to_array(tickets_csv)

@priorities = get_priorities
if @priorities
  @priorities.each do |priority|
    puts priority.inspect
    # puts "id=#{priority['id']} name='#{priority['name']}' #{priority['custom']}"
  end
else
  puts "Cannot get priorities!"
  exit
end

@fields = get_fields

if @fields
  @fields.each do |field|
    puts "id=#{field['id']} name='#{field['name']}' #{field['custom']}"
  end
else
  puts "Cannot get fields!"
  exit
end

@assembla = get_field('Assembla')

if @assembla
  puts "Assembla id = '#{@assembla['id']}'"
else
  puts "Assembla custom field is missing, please define in Jira"
  exit
end

exit

tickets.each do |ticket|
  create_ticket(ticket)
end

write_csv_file(jira_tickets_csv, @jira_tickets)