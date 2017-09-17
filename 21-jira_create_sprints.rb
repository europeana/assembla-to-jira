# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = ENV['JIRA_API_PROJECT_NAME']
JIRA_PROJECT_NAME = SPACE_NAME + (@debug ? ' TEST' : '')

MILESTONE_PLANNER_TYPES = %w(none backlog current unknown)

JIRA_AGILE_HOST = ENV['JIRA_AGILE_HOST']
URL_JIRA_BOARDS = "#{JIRA_AGILE_HOST}/board"
URL_JIRA_SPRINTS = "#{JIRA_AGILE_HOST}/sprint"

# JIRA_AGILE_BOARD=name:Europeana Collections Scrum Board,type:scrum
JIRA_AGILE_BOARD = ENV['JIRA_AGILE_BOARD']

@board_name = JIRA_AGILE_BOARD.split(',')[0].split(':')[1]
@board_type = JIRA_AGILE_BOARD.split(',')[1].split(':')[1]

space = get_space(SPACE_NAME)
dirname = get_output_dirname(space, 'assembla')

assembla_milestones_csv = "#{dirname}/milestones.csv"
@milestones_assembla = csv_to_array(assembla_milestones_csv)

jira_projects_csv = "#{OUTPUT_DIR_JIRA}/jira-projects.csv"
@projects_jira = csv_to_array(jira_projects_csv)

puts "\nTotal milestones: #{@milestones_assembla.length}"

# milestone: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
@milestones_assembla.each do |milestone|
  puts "* #{milestone['id']} #{milestone['title']} (#{MILESTONE_PLANNER_TYPES[milestone['planner_type'].to_i]}) => #{milestone['is_completed'] ? '' : 'not'} completed"
end
puts

@sprints = @milestones_assembla.select{ |milestone| milestone['title'] =~ /sprint/i }
@sprints.sort! { |x,y| y['start_date'] <=> x['start_date'] }

puts "\nTotal sprints: #{@sprints.length}"

@sprints.each do |sprint|
  puts "* #{sprint['title']}"
end
puts

# POST /rest/api/2/filter
# {
#     "name": "Filter for Europeana Collections",
#     "description": "List all issues ordered by rank",
#     "jql": "project = ECT ORDER BY Rank ASC"
# }
def jira_create_filter(filter)
  result = nil
  url = URL_JIRA_FILTERS
  payload = filter.to_json
  begin
    response = RestClient::Request.execute(method: :post, url: url, payload: payload, headers: JIRA_HEADERS)
    result = JSON.parse(response.body)
    if result
      puts "POST #{url} name='#{filter[:name]}' => OK"
    end
  rescue RestClient::ExceptionWithResponse => e
    rest_client_exception(e, 'POST', url, payload)
  rescue => e
    puts "POST #{url} name='#{filter[:name]}', NOK (#{e.message})"
  end
  result
end

def jira_get_filter_by_name(name)
  result = nil
  url = URL_JIRA_FILTERS
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

def jira_create_board(project, name, type, filter_id)
  Goodbye("Invalid name='#{name}'") unless name && name.is_a?(String) && name.length.positive?
  Goodbye("Invalid type='#{type}', valid values: 'scrum' or 'kanban'") unless type && type.is_a?(String) && (type == 'scrum' || type == 'kanban')
  result = nil
  url = URL_JIRA_BOARDS
  payload = {
    name: name,
    type: type,
    filterId: filter_id,
    location: {
      type: 'project',
      projectKeyOrId: project['key']
    }
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

def jira_get_boards
  result = nil
  begin
    response = RestClient::Request.execute(method: :get, url: URL_JIRA_BOARDS, headers: JIRA_HEADERS)
    result = JSON.parse(response)
    if result
      result.each do |r|
        r.delete_if { |k, _| k.to_s =~ /expand|self|avatarurls/i }
      end
      puts "GET #{URL_JIRA_BOARDS} => OK (#{result.length})"
    end
  rescue => e
    puts "GET #{URL_JIRA_BOARDS} => NOK (#{e.message})"
  end
  result
end

def jira_get_board_by_name(name)
  result = nil
  url = URL_JIRA_BOARDS
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
    originBoardId: board['id'],
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

def jira_get_sprint_by_name(board, name)
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

project = @projects_jira.detect { |project| project['name'] == JIRA_PROJECT_NAME }
goodbye("Cannot find project with name='#{JIRA_PROJECT_NAME}'") unless project

# filter = {
#   name: "Filter for #{project['name']}",
#   description: "List all issues ordered by rank",
#   jql: "project = #{project['key']} ORDER BY Rank ASC"
# }
#
# board_filter = jira_get_filter_by_name(filter[:name]) || jira_create_filter(filter)

# jira_create_board(project, @board_name, @board_type, filter['id']) unless jira_get_board_by_name(@board_name)
@board = jira_get_board_by_name(@board_name)

unless @board
  goodbye("Cannot find board, please create:\n" +
              "Board name: '#{@board_name}'\n" +
              "Type:       '#{@board_type}'\n" +
              "Project:    '#{JIRA_PROJECT_NAME}'"
  )
end

@jira_sprints = []

# sprint: id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
@sprints.each do |sprint|
  result = jira_get_sprint_by_name(@board, sprint['title']) || jira_create_sprint(@board, sprint)
  @jira_sprints << result.merge(assembla_id: sprint['id']) if result
end

puts "\nTotal updates: #{@jira_sprints.length}"
sprints_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-sprints.csv"
write_csv_file(sprints_jira_csv, @jira_sprints)
