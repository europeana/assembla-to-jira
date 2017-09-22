# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

MILESTONE_PLANNER_TYPES = %w(none backlog current unknown)

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space, 'assembla')

assembla_milestones_csv = "#{dirname}/milestones.csv"
@milestones_assembla = csv_to_array(assembla_milestones_csv)

puts "\nTotal milestones: #{@milestones_assembla.length}"

jira_projects_csv = "#{OUTPUT_DIR_JIRA}/jira-projects.csv"
jira_tickets_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets-all.csv"

@projects_jira = csv_to_array(jira_projects_csv)
@tickets_jira = csv_to_array(jira_tickets_csv)

# milestone: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
@milestones_assembla.each do |milestone|
  puts "* #{milestone['id']} #{milestone['title']} (#{MILESTONE_PLANNER_TYPES[milestone['planner_type'].to_i]})" \
       " => #{milestone['is_completed'] ? '' : 'not'} completed"
end
puts

@sprints = @milestones_assembla.select{ |milestone| milestone['title'] =~ /sprint/i }

# Need to sort the sprints so that they appear in the correct order.
@sprints.sort! { |x,y| y['start_date'] <=> x['start_date'] }

puts "Total sprints: #{@sprints.length}"

@sprints.each do |sprint|
  puts "* #{sprint['title']}"
end
puts

# GET /rest/agile/1.0/board/{boardId}/sprint
def jira_get_sprint(board, sprint)
  name = sprint['title']
  result = nil
  url = "#{URL_JIRA_BOARDS}/#{board['id']}/sprint"
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    # max_results = body['maxResults'].to_i
    # start_at = body['startAt'].to_i
    # is_last = body['isLast']
    values = body['values']
    if values
      result = values.detect { |h| h['name'] == name }
      if result
        result.delete_if { |k, _| k =~ /self/i }
        puts "GET #{url} name='#{name}' => FOUND"
      else
        puts "GET #{url} name='#{name}' => NOT FOUND"
      end
    end
  rescue => e
    puts "GET #{url} name='#{name}' => NOK (#{e.message})"
  end
  result
end

def jira_create_sprint(board, sprint)
  result = nil
  name = sprint['title']
  url = URL_JIRA_SPRINTS
  payload = {
    name: name,
    startDate: sprint['start_date'],
    endDate: sprint['due_date'],
    originBoardId: board['id']
    # "goal": "sprint 1 goal"
  }.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    if result
      result.delete_if { |k, _| k =~ /self/i }
      puts "POST #{url} name='#{name}' => OK"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} name='#{name}' => NOK (#{e.message})"
  end
  result
end

# POST /rest/agile/1.0/sprint/{sprintId}/issue
def jira_move_issues_to_sprint(sprint, tickets)
  # Moves issues to a sprint, for a given sprint Id. Issues can only be moved to open or active sprints. The maximum
  # number of issues that can be moved in one operation is 50.
  len = tickets.length
  goodbye("Cannot move issues to sprint, len=#{len} (must be less than 50") if len > 50
  result = nil
  url = "#{URL_JIRA_SPRINTS}/#{sprint['id']}/issue"
  issues = tickets.map { |ticket| ticket['jira_ticket_key'] }
  payload = {
    issues: issues
  }.to_json
  begin
    RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "POST #{url} name='#{sprint['name']}' #{issues.length} issues [#{issues.join(',')}] => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} => NOK (#{e.message})"
  end
  result
end

# PUT /rest/agile/1.0/sprint/{sprintId}
def jira_update_sprint_state(sprint, state)
  result = nil
  name = sprint['name']
  start_date = sprint['startDate']
  end_date = sprint['endDate']
  url = "#{URL_JIRA_SPRINTS}/#{sprint['id']}"
  payload = {
    name: name,
    state: state,
    startDate: start_date,
    endDate: end_date
  }.to_json
  begin
    RestClient::Request.execute(method: :put, url: url, payload: payload, headers: JIRA_HEADERS)
    puts "PUT #{url} name='#{name}', state='#{state}' => OK"
    result = true
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'PUT', url, payload)
  rescue => e
    puts "PUT #{url} name='#{name}', state='#{state}' => NOK (#{e.message})"
  end
  result
end

project = @projects_jira.detect { |p| p['name'] == JIRA_PROJECT_NAME }
goodbye("Cannot find project with name='#{JIRA_PROJECT_NAME}'") unless project

@board = jira_get_board_by_project_name(JIRA_PROJECT_NAME)

@jira_sprints = []

# sprint: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
# next_sprint: id,state,name,startDate,endDate,originBoardId,assembla_id
@sprints.each do |sprint|
  next_sprint = jira_get_sprint(@board, sprint) || jira_create_sprint(@board, sprint)
  if next_sprint
    @tickets_sprint = @tickets_jira.select { |ticket| ticket['milestone_name'] == sprint['title'] }
    issues = @tickets_sprint.map { |ticket| ticket['jira_ticket_key'] }
    while @tickets_sprint.length.positive?
      @tickets_sprint_slice = @tickets_sprint.slice!(0,50)
      jira_update_sprint_state(next_sprint, 'active')
      jira_move_issues_to_sprint(next_sprint, @tickets_sprint_slice)
    end
    @jira_sprints << next_sprint.merge(issues: issues.join(',')).merge(assembla_id: sprint['id'])
  end
end

# First sprint should be 'active' and the other 'closed'
jira_update_sprint_state(@jira_sprints.first, 'active')

puts "\nTotal updates: #{@jira_sprints.length}"
sprints_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-sprints.csv"
write_csv_file(sprints_jira_csv, @jira_sprints)

